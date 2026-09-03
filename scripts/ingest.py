import os
import hashlib
import uuid
import re
import argparse
import subprocess
import psycopg2
from psycopg2.extras import execute_values
import sys

MIN_AVG_CHARS_PER_PAGE = 50

def get_source_id(file_path):
    """Genera un source_id deterministico basato sul path assoluto del file."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, os.path.abspath(file_path)))

def get_file_sha256(file_path):
    """Calcola lo sha256 del contenuto del file in modalità binaria."""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()

def split_text_into_chunks(content, max_chunk_size=1000):
    """Divide il contenuto in chunk separati da righe vuote, poi suddivide chunk troppo lunghi.

    Ritorna una lista di stringhe con chunk_index progressivo implicito
    (l'indice nella lista), indipendente dal numero di paragrafi di origine.
    """
    paragraphs = re.split(r'\n\s*\n', content)
    chunks = []
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        if len(para) <= max_chunk_size:
            chunks.append(para)
        else:
            # Suddivide in blocchi di max_chunk_size senza spezzare le parole
            words = para.split()
            current_chunk = ""
            for word in words:
                if len(current_chunk) + len(word) + 1 <= max_chunk_size:
                    if current_chunk:
                        current_chunk += " " + word
                    else:
                        current_chunk = word
                else:
                    if current_chunk:
                        chunks.append(current_chunk)
                    current_chunk = word
            if current_chunk:
                chunks.append(current_chunk)
    return chunks

def extract_pdf_pages(file_path):
    """Estrae il testo di un PDF pagina per pagina via pdftotext (poppler-utils).

    Ritorna una lista di stringhe, una per pagina. Propaga qualunque
    eccezione (binario assente, PDF corrotto, ecc.) al chiamante: la
    gestione errori/soglia resta nel loop principale.
    """
    result = subprocess.run(
        ["pdftotext", "-layout", file_path, "-"],
        capture_output=True, text=True, check=True
    )
    pages = result.stdout.split("\f")
    if pages and pages[-1] == "":
        pages.pop()
    return pages

def main(root_dir):
    # Validazione directory
    if not os.path.isdir(root_dir):
        print(f"[ingest] Errore: la directory '{root_dir}' non esiste.")
        sys.exit(1)

    # Connessione al database
    try:
        conn = psycopg2.connect(
            host="homelab-ai-postgres",
            port=5432,
            database=os.environ.get("POSTGRES_DB"),
            user=os.environ.get("POSTGRES_USER"),
            password=os.environ.get("POSTGRES_PASSWORD")
        )
        conn.autocommit = False
    except Exception as e:
        print(f"[ingest] Errore di connessione al database: {e}")
        sys.exit(1)

    # Variabili di stato
    total_files = 0
    new_files = 0
    updated_files = 0
    skipped_files = 0
    error_files = 0

    try:
        with conn.cursor() as cur:
            for root, _, files in os.walk(root_dir):
                for file in files:
                    if not file.endswith(('.txt', '.md', '.pdf')):
                        continue

                    file_path = os.path.join(root, file)
                    total_files += 1
                    is_pdf = file.endswith('.pdf')

                    try:
                        # Calcolo SHA256 contenuto
                        file_sha256 = get_file_sha256(file_path)

                        # Genera source_id
                        source_id = get_source_id(file_path)

                        # Recupera informazioni esistenti
                        cur.execute("""
                            SELECT sha256
                            FROM sources
                            WHERE file_path = %s
                        """, (file_path,))
                        row = cur.fetchone()

                        if is_pdf:
                            mime_type = "application/pdf"
                        elif file.endswith('.md'):
                            mime_type = "text/markdown"
                        else:
                            mime_type = "text/plain"
                        doc_title = os.path.splitext(file)[0]

                        if not row:
                            # Nuovo file
                            cur.execute("""
                                INSERT INTO sources (
                                    source_id, sha256, file_path, document_title,
                                    mime_type, parser_version, ingestion_version, status
                                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                            """, (
                                source_id, file_sha256, file_path, doc_title,
                                mime_type, "1.0.0", "1.0.0", "ingested"
                            ))
                            new_files += 1
                            is_updated = True
                        else:
                            existing_sha256 = row[0]
                            if existing_sha256 != file_sha256:
                                # Aggiorna file
                                cur.execute("""
                                    UPDATE sources
                                    SET sha256 = %s, document_title = %s,
                                        mime_type = %s, parser_version = %s,
                                        ingestion_version = %s, status = %s,
                                        updated_at = now()
                                    WHERE file_path = %s
                                """, (
                                    file_sha256, doc_title, mime_type,
                                    "1.0.0", "1.0.0", "ingested", file_path
                                ))
                                updated_files += 1
                                is_updated = True
                            else:
                                # File non cambiato
                                skipped_files += 1
                                print(f"[ingest] {file_path} - Skipped (unchanged)")
                                conn.commit()
                                continue

                        # Il file e' nuovo o cambiato: rigenera i chunk
                        cur.execute("DELETE FROM chunks WHERE source_id = %s", (source_id,))

                        if is_pdf:
                            pages = extract_pdf_pages(file_path)
                            avg_chars = (
                                sum(len(p.strip()) for p in pages) / len(pages)
                                if pages else 0
                            )
                            if avg_chars < MIN_AVG_CHARS_PER_PAGE:
                                cur.execute("""
                                    UPDATE sources
                                    SET status = 'error', updated_at = now()
                                    WHERE source_id = %s
                                """, (source_id,))
                                print(f"[ingest] {file_path} - PROBABILE SCANSIONE/OCR DI BASSA QUALITA', serve consensus OCR (M4) - saltato")
                                error_files += 1
                                conn.commit()
                                continue

                            chunk_records = []
                            index = 0
                            for page_num, page_text in enumerate(pages, start=1):
                                for chunk_text in split_text_into_chunks(page_text):
                                    chunk_records.append((
                                        f"{source_id}:{index}",
                                        source_id,
                                        index,
                                        page_num,  # page
                                        None,  # section
                                        None,  # heading
                                        chunk_text,
                                        len(chunk_text)
                                    ))
                                    index += 1
                        else:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()

                            chunk_texts = split_text_into_chunks(content)
                            chunk_records = [
                                (
                                    f"{source_id}:{index}",
                                    source_id,
                                    index,
                                    None,  # page
                                    None,  # section
                                    None,  # heading
                                    chunk_text,
                                    len(chunk_text)
                                )
                                for index, chunk_text in enumerate(chunk_texts)
                            ]

                        if chunk_records:
                            execute_values(cur, """
                                INSERT INTO chunks (
                                    chunk_id, source_id, chunk_index, page,
                                    section, heading, content, char_count
                                ) VALUES %s
                            """, chunk_records, page_size=100)

                        print(f"[ingest] {file_path} - Updated ({len(chunk_records)} chunks)")
                        conn.commit()

                    except Exception as e:
                        conn.rollback()
                        error_files += 1
                        print(f"[ingest] Errore elaborando {file_path}: {e}")

    finally:
        conn.close()

    # Riepilogo
    print(f"[ingest] Riepilogo: {total_files} file totali, {new_files} nuovi, {updated_files} aggiornati, {skipped_files} skippati, {error_files} errori")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest files into PostgreSQL database.")
    parser.add_argument("root_dir", help="Directory root da cui fare il walk ricorsivo.")
    args = parser.parse_args()
    main(args.root_dir)
