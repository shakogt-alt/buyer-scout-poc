-- Buyer Scout PoC — схема данных
-- SQLite для PoC. Типы выбраны так, чтобы переезд на Postgres был механическим.
-- Ничего сверх этих полей не добавлять: см. CLAUDE.md, раздел "Данные и приватность".

-- ---------------------------------------------------------------------------
-- Raw Message Store
-- ---------------------------------------------------------------------------

CREATE TABLE raw_messages (
    pk              INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id        TEXT    NOT NULL,
    group_name      TEXT    NOT NULL,
    group_type      TEXT    NOT NULL CHECK (group_type IN ('A','B','C','D','E')),
    message_id      TEXT    NOT NULL,
    posted_at       TEXT    NOT NULL,           -- ISO8601, время публикации
    author_id       TEXT,                       -- в пределах разрешённого платформой
    text            TEXT    NOT NULL,
    reply_to_text   TEXT,
    permalink       TEXT,
    lang            TEXT,                       -- ru / en / ka / other
    ingested_at     TEXT    NOT NULL,
    processed_at    TEXT,                       -- для Signal Latency
    stage0_verdict  TEXT    CHECK (stage0_verdict IN ('pass','drop')),
    stage0_rule     TEXT,                       -- какое правило отсекло
    UNIQUE (group_id, message_id)
);

CREATE INDEX idx_raw_posted     ON raw_messages (posted_at);
CREATE INDEX idx_raw_group      ON raw_messages (group_id, posted_at);
CREATE INDEX idx_raw_stage0     ON raw_messages (stage0_verdict);

-- ---------------------------------------------------------------------------
-- Вердикты AI-стадий
-- ---------------------------------------------------------------------------

CREATE TABLE stage1_relevance (
    message_pk      INTEGER PRIMARY KEY REFERENCES raw_messages(pk) ON DELETE CASCADE,
    verdict         TEXT    NOT NULL CHECK (verdict IN ('RELEVANT','IRRELEVANT')),
    confidence      REAL,
    model           TEXT    NOT NULL,
    run_id          INTEGER REFERENCES pipeline_runs(id),
    processed_at    TEXT    NOT NULL
);

CREATE TABLE stage2_intent (
    message_pk      INTEGER PRIMARY KEY REFERENCES raw_messages(pk) ON DELETE CASCADE,
    intent_type     TEXT    CHECK (intent_type IN ('BUY','RENT','INVEST','SELL','UNKNOWN')),
    s_level         TEXT    CHECK (s_level IN ('S1','S2','S3','S4','S5')),
    intent_score    INTEGER CHECK (intent_score BETWEEN 0 AND 100),
    is_agent_or_ad  INTEGER NOT NULL DEFAULT 0,  -- 1 = агент/реклама/собственник
    confidence      REAL,
    explanation     TEXT,
    model           TEXT    NOT NULL,
    run_id          INTEGER REFERENCES pipeline_runs(id),
    processed_at    TEXT    NOT NULL
);

CREATE INDEX idx_stage2_level ON stage2_intent (s_level, intent_score);

-- ---------------------------------------------------------------------------
-- Buyer Signals — результат Stage 3
-- ---------------------------------------------------------------------------

CREATE TABLE buyer_signals (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    message_pk         INTEGER NOT NULL UNIQUE REFERENCES raw_messages(pk) ON DELETE CASCADE,
    profile_id         INTEGER REFERENCES buyer_profiles(id),
    intent_type        TEXT,
    intent_score       INTEGER,
    s_level            TEXT,
    city               TEXT,
    district           TEXT,
    budget_min         REAL,
    budget_max         REAL,
    currency           TEXT,
    property_type      TEXT,
    bedrooms           INTEGER,
    rooms              INTEGER,
    area_min           REAL,
    area_max           REAL,
    build_status       TEXT CHECK (build_status IN ('new_build','secondary','unknown')),
    condition_frame    TEXT,
    purchase_purpose   TEXT,
    desired_timeline   TEXT,
    mortgage_or_cash   TEXT,
    language           TEXT,
    contactability     TEXT CHECK (contactability IN ('direct','via_group','none')),
    ai_summary         TEXT,
    explanation        TEXT,
    confidence         REAL,
    model              TEXT NOT NULL,
    run_id             INTEGER REFERENCES pipeline_runs(id),
    detected_at        TEXT NOT NULL
);

-- Дедупликация: source + author_identifier + временное окно
CREATE TABLE buyer_profiles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    author_id       TEXT    NOT NULL,
    group_id        TEXT    NOT NULL,
    first_seen_at   TEXT    NOT NULL,
    last_seen_at    TEXT    NOT NULL,
    signal_count    INTEGER NOT NULL DEFAULT 1,
    max_s_level     TEXT,
    max_intent_score INTEGER,
    intent_trend    TEXT CHECK (intent_trend IN ('increasing','flat','decreasing')),
    contactable     INTEGER NOT NULL DEFAULT 0,
    UNIQUE (author_id, group_id)
);

-- ---------------------------------------------------------------------------
-- Ручная разметка — основа Precision и False Positive Rate
-- ---------------------------------------------------------------------------

CREATE TABLE agent_labels (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    signal_id    INTEGER NOT NULL REFERENCES buyer_signals(id) ON DELETE CASCADE,
    label        TEXT    NOT NULL CHECK (label IN (
                     'good_signal','not_a_buyer','already_contacted',
                     'duplicate','spam','wrong_location','wrong_intent')),
    note         TEXT,
    labeled_at   TEXT    NOT NULL
);

CREATE INDEX idx_labels_signal ON agent_labels (signal_id);

-- ---------------------------------------------------------------------------
-- Учёт прогонов, токенов и стоимости
-- ---------------------------------------------------------------------------

CREATE TABLE pipeline_runs (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    stage                   TEXT    NOT NULL CHECK (stage IN ('stage1','stage2','stage3')),
    model                   TEXT    NOT NULL,
    prompt_file             TEXT    NOT NULL,
    prompt_sha              TEXT    NOT NULL,   -- хеш промпта: какой версией считали
    batch_size              INTEGER,
    used_batch_api          INTEGER NOT NULL DEFAULT 0,
    messages_in             INTEGER NOT NULL,
    input_tokens            INTEGER,
    output_tokens           INTEGER,
    cache_read_tokens       INTEGER,
    cache_write_tokens      INTEGER,
    est_cost_usd            REAL,
    started_at              TEXT    NOT NULL,
    finished_at             TEXT
);

-- ---------------------------------------------------------------------------
-- Source Quality Score
-- ---------------------------------------------------------------------------

CREATE VIEW source_stats AS
SELECT
    r.group_id,
    r.group_name,
    r.group_type,
    COUNT(*)                                                   AS raw_messages,
    SUM(CASE WHEN s2.s_level IN ('S4','S5') THEN 1 ELSE 0 END) AS qualified_signals,
    ROUND(1000.0 * SUM(CASE WHEN s2.s_level IN ('S4','S5') THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                            AS qualified_per_1k,
    ROUND(AVG(s2.intent_score), 1)                             AS avg_intent_score
FROM raw_messages r
LEFT JOIN stage2_intent s2 ON s2.message_pk = r.pk
GROUP BY r.group_id;
