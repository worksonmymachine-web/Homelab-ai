-- Schema for document ingestion: sources and their chunked content.

CREATE TABLE sources (
    source_id           TEXT PRIMARY KEY,
    sha256              TEXT NOT NULL,
    file_path           TEXT NOT NULL,
    document_title      TEXT,
    course              TEXT,
    professor           TEXT,
    source_url          TEXT,
    mime_type           TEXT,
    parser_version      TEXT NOT NULL,
    ingestion_version   TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'ingested',
    retrieved_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE chunks (
    chunk_id      TEXT PRIMARY KEY,
    source_id     TEXT NOT NULL REFERENCES sources(source_id) ON DELETE CASCADE,
    chunk_index   INTEGER NOT NULL,
    page          INTEGER,
    section       TEXT,
    heading       TEXT,
    content       TEXT NOT NULL,
    char_count    INTEGER NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chunks_source_id ON chunks(source_id);
CREATE UNIQUE INDEX idx_sources_file_path ON sources(file_path);
