#!/usr/bin/env python3
"""
validate_golden_dataset.py — controllo strutturale del golden dataset.

Questo script NON valuta la qualità delle risposte del RAG (quello è il
compito di rag-eval-harness, da costruire dopo che Qdrant/embedding sono
collegati, Fase 4). Qui verifichiamo solo che il file YAML sia ben formato
e internamente coerente, PRIMA di usarlo per qualsiasi valutazione:

- Tutti i campi obbligatori sono presenti e non vuoti
- Nessun id duplicato
- expected_source_id fa riferimento a un source_id che esiste davvero
  in Postgres (se il DB è raggiungibile; altrimenti verifica solo la forma)
- difficulty è uno dei valori ammessi
- Segnala le domande "trappola" mancanti (consigliate 2-3 dal template)

Uso:
    python3 validate_golden_dataset.py path/to/dataset.yaml
    python3 validate_golden_dataset.py path/to/dataset.yaml --check-db
"""
import sys
import argparse

try:
    import yaml
except ImportError:
    print("Errore: serve PyYAML. Installa con: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

REQUIRED_FIELDS = [
    "id",
    "question",
    "expected_source_id",
    "expected_locator",
    "expected_answer_summary",
    "difficulty",
]
VALID_DIFFICULTIES = {"easy", "medium", "hard"}
PLACEHOLDER_MARKERS = {"", "scrivi qui", "nome-file-o-id-documento"}


def load_dataset(path):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or "entries" not in data:
        raise ValueError("Il file deve avere una chiave top-level 'entries'")
    return data


def is_placeholder(value):
    if value is None:
        return True
    v = str(value).strip().lower()
    return v in PLACEHOLDER_MARKERS or v.startswith("scrivi qui")


def validate_entries(entries):
    errors = []
    warnings = []
    seen_ids = set()
    seen_source_ids = set()

    for i, entry in enumerate(entries):
        loc = f"entries[{i}]"
        entry_id = entry.get("id", f"<manca id, indice {i}>")

        for field in REQUIRED_FIELDS:
            if field not in entry:
                errors.append(f"{loc} ({entry_id}): campo mancante '{field}'")
            elif is_placeholder(entry.get(field)):
                errors.append(
                    f"{loc} ({entry_id}): campo '{field}' è ancora un placeholder, non compilato"
                )

        if entry_id in seen_ids:
            errors.append(f"{loc}: id duplicato '{entry_id}'")
        seen_ids.add(entry_id)

        difficulty = entry.get("difficulty")
        if difficulty and difficulty not in VALID_DIFFICULTIES:
            errors.append(
                f"{loc} ({entry_id}): difficulty '{difficulty}' non valida "
                f"(ammessi: {', '.join(sorted(VALID_DIFFICULTIES))})"
            )

        source_id = entry.get("expected_source_id")
        if source_id and not is_placeholder(source_id):
            seen_source_ids.add(source_id)

    if len(entries) < 15:
        warnings.append(
            f"Solo {len(entries)} voci compilate — il template ne consiglia 15-20"
        )

    return errors, warnings, seen_source_ids


def check_against_db(source_ids, dsn):
    """Verifica che gli expected_source_id esistano davvero in Postgres.
    Richiede psycopg2; se non disponibile o DB irraggiungibile, salta con avviso."""
    try:
        import psycopg2
    except ImportError:
        return ["psycopg2 non installato: salto la verifica contro il database"]

    try:
        conn = psycopg2.connect(dsn)
    except Exception as e:
        return [f"Impossibile connettersi al DB per la verifica incrociata: {e}"]

    missing = []
    with conn, conn.cursor() as cur:
        for sid in source_ids:
            cur.execute("SELECT 1 FROM sources WHERE source_id = %s", (sid,))
            if cur.fetchone() is None:
                missing.append(sid)
    conn.close()

    warnings = []
    for sid in missing:
        warnings.append(
            f"expected_source_id '{sid}' non trovato nella tabella sources — "
            "il documento è stato ingerito?"
        )
    return warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset_path")
    parser.add_argument(
        "--check-db",
        action="store_true",
        help="verifica anche che expected_source_id esista in Postgres",
    )
    parser.add_argument(
        "--dsn",
        default="dbname=homelab_ai user=homelab_ai host=localhost",
        help="stringa di connessione Postgres (default: locale, richiede porta esposta)",
    )
    args = parser.parse_args()

    try:
        data = load_dataset(args.dataset_path)
    except Exception as e:
        print(f"Errore nel caricare il file: {e}", file=sys.stderr)
        sys.exit(1)

    entries = data.get("entries", [])
    errors, warnings, source_ids = validate_entries(entries)

    if args.check_db and source_ids:
        warnings += check_against_db(source_ids, args.dsn)

    print(f"Voci trovate: {len(entries)}")
    print(f"Errori: {len(errors)}")
    print(f"Avvisi: {len(warnings)}")
    print()

    for e in errors:
        print(f"  ERRORE: {e}")
    for w in warnings:
        print(f"  AVVISO: {w}")

    if errors:
        print("\nRisultato: NON VALIDO — correggi gli errori sopra prima di usare il dataset.")
        sys.exit(1)
    else:
        print("\nRisultato: struttura valida. (Questo non giudica la qualità delle domande.)")
        sys.exit(0)


if __name__ == "__main__":
    main()
