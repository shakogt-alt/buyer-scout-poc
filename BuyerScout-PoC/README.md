# Buyer Scout — PoC

Изолированный исследовательский PoC для KleekTo. Проверяет одну гипотезу:

> В выбранных Telegram-группах существует достаточный стабильный поток уникальных,
> контактируемых buyer signals по недвижимости Грузии, чтобы Buyer Scout
> представлял практическую ценность для агента KleekTo.

Итоговая метрика — **Contactable Qualified Buyers / Day**.

Это не продукт и не часть KleekTo. Результат эксперимента — решение
**GO / ITERATE / DROP**, а не работающая функция.

## Структура

```
BuyerScout-PoC/
├── CLAUDE.md                     инструкции для Claude Code — читать первым
├── README.md
├── .env.example
├── .gitignore                    data/ и .env никогда не коммитятся
├── config/
│   └── sources.example.yaml      10–20 групп, распределение по типам A–E
├── docs/
│   ├── CONCEPT.md                полный концепт Buyer Scout
│   ├── RUBRIC.md                 S1–S5, Intent Score, поля извлечения
│   └── METRICS.md                журнал результатов эксперимента
├── prompts/
│   ├── stage1_relevance.md       Haiku — релевантность
│   ├── stage2_intent.md          Haiku — intent + S-level + score
│   └── stage3_extraction.md      Sonnet 5 — структурированное извлечение
├── db/
│   └── schema.sql
└── scripts/
```

## Старт

```bash
cp .env.example .env                       # вписать ANTHROPIC_API_KEY и Telegram
cp config/sources.example.yaml config/sources.yaml   # вписать реальные группы
```

Дальше открыть Claude Code в корне репозитория. Он читает `CLAUDE.md` и строит
пайплайн по стадиям.

## Пайплайн

| Стадия | Модель | Что делает | Поток |
| --- | --- | --- | --- |
| Stage 0 | — | локальные правила, без ИИ | 100% |
| Stage 1 | Haiku 4.5 | релевантность теме | ~70% |
| Stage 2 | Haiku 4.5 | intent, S-level, intent score | ~10% |
| Stage 3 | Sonnet 5 | извлечение полей, summary, explanation | ~2% |

Батчинг, prompt caching и Batch API обязательны на всех стадиях — см. `CLAUDE.md`.
Без них прогон дорожает примерно вчетверо.

Ориентир стоимости: около $10 за 7-дневный прогон на 15 группах и ~100 000
сообщений. Это переменные расходы на API, не смета разработки.

## Границы

PoC не отправляет сообщения потенциальным покупателям — ни автоматически, ни
по запросу. Решение о контакте принимает агент, вне этой системы.

Мониторятся только группы, явно перечисленные в `config/sources.yaml`, к которым
тестовый аккаунт имеет законный доступ. Ограничения платформы не обходятся.

Raw Message Store содержит персональные данные третьих лиц. Retention по умолчанию
30 дней, `data/` в `.gitignore`.
