# Журнал результатов

Заполняется по ходу эксперимента. Решение принимается по этим цифрам, не по
впечатлению от просмотра ленты.

## Параметры прогона

| | |
| --- | --- |
| Период сбора | |
| Количество источников | |
| Распределение по типам A/B/C/D/E | |
| Версия промптов (`prompt_sha`) | |

## Воронка

```
Raw Messages
  → Candidate Signals
    → Qualified Signals (S4–S5)
      → Unique Buyers
        → Contactable Buyers
```

| Ступень | Значение |
| --- | --- |
| Raw Messages | |
| Отсеяно на Stage 0 | |
| Candidate Signals (Stage 1 RELEVANT) | |
| Qualified Signals (S4–S5) | |
| Unique Buyers после дедупликации | |
| Contactable Buyers | |

## Главные метрики

| Метрика | Значение |
| --- | --- |
| Raw Messages / Day | |
| Buyer Signals / Day | |
| Qualified Buyer Signals / Day | |
| Unique Buyers / Day | |
| **Contactable Qualified Buyers / Day** | |
| Precision (ручная проверка S4/S5) | |
| False Positive Rate | |
| Signal Latency, медиана | |

## Source Yield

| Группа | Тип | Messages | Qualified / 1k | FP rate | Средний score |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## Расходы

| Стадия | Сообщений | Токены in / out / cache | USD |
| --- | --- | --- | --- |
| Stage 1 | | | |
| Stage 2 | | | |
| Stage 3 | | | |
| **Итого** | | | |

## Решение

Ориентиры из концепта, §24:

| Качественных уникальных сигналов в день | Вывод |
| --- | --- |
| менее 1 на всю выборку | слабая ценность |
| несколько в день | перспективный вспомогательный инструмент |
| десятки в день | потенциально сильный capability KleekTo |

Объём нельзя рассматривать отдельно от precision: 50 сигналов в день при
40 ложных срабатываниях хуже, чем 8 действительно качественных.

**Решение:** GO / ITERATE / DROP — _______

**Обоснование:**
