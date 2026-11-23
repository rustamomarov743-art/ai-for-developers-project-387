# Подключение OpenCode к GitHub Actions

## Context

Нужно выполнить лаг 1 из `my/task1.md`: OpenCode должен запускаться по командам доверенных участников в issue и PR, отвечать от имени GitHub App и работать с настройками этого репозитория.

Текущее состояние:
- `.github/workflows/opencode.yml` отсутствует; основная ветка — `main`, репозиторий публичный.
- Скиллы `to-spec`, `to-tickets` и `implement-spec` уже хранятся в `.agents/skills/`; OpenCode поддерживает этот каталог напрямую, поэтому дополнительная установка проектных скиллов не нужна.
- Трекер настроен на GitHub Issues в `docs/agents/issue-tracker.md`.
- Команды в `AGENTS.md` соответствуют `mise.toml`, включая полную проверку `mise run check`; правки там не требуются.
- В Actions Secrets сейчас виден только `HEXLET_ID`; установку OpenCode App нужно подтвердить вручную.

## Approach

Использовать стандартную авторизацию OpenCode через GitHub App и OIDC, без `GITHUB_TOKEN` с правами записи и без `pull_request_target`. Конфигурацию подготовить в PR, после ручной установки приложения и добавления секрета влить в `main`, затем проверить реальный вызов в issue.

Основа — [официальная интеграция OpenCode с GitHub](https://opencode.ai/v1/docs/github/) и [документация Kimi Code по OpenCode](https://www.kimi.com/code/docs/en/third-party-tools/opencode).

## Key changes

### 1. Ручные предусловия в GitHub и OpenCode

1. Установить [OpenCode App](https://github.com/apps/opencode-agent) именно на `rustamomarov743-art/ai-for-developers-project-387` и проверить установку в настройках репозитория/аккаунта.
2. В Kimi Code Console создать ключ подписки **Kimi For Coding** для международного региона `kimi.ai` и добавить его в **Settings → Secrets and variables → Actions** как `KIMI_API_KEY`. Это не ключ Moonshot AI Open Platform и не `OPENCODE_API_KEY`. Значение ключа не передавать агенту и не сохранять в репозитории.
3. Учитывать недельную квоту подписки Kimi Code. Отзыв ключа отдельно не демонстрировать, а работу **Cancel workflow** и **Disable workflow** проверить на реальном запуске; после проверки воркфлоу обязательно включить обратно.

### 2. Создать `.github/workflows/opencode.yml`

Настроить один job `opencode` на `ubuntu-latest`:
- события `issue_comment` и `pull_request_review_comment`, для обоих только `types: [created]`;
- job-level `if`: в комментарии есть `/oc` или `/opencode`, `author_association` равен `OWNER`, `MEMBER` или `COLLABORATOR`, а тип автора не `Bot`;
- `timeout-minutes: 15`;
- `concurrency` с группой по номеру issue или PR (`github.event.issue.number || github.event.pull_request.number`) и `cancel-in-progress: true`, чтобы новая команда в том же обсуждении отменяла предыдущий запуск;
- permissions только `contents: read` и `id-token: write`;
- `actions/checkout` с `fetch-depth: 1` и `persist-credentials: false`, без checkout кода из fork или небезопасного `pull_request_target`;
- `anomalyco/opencode/github@latest` со стандартным OIDC-обменом токена GitHub App;
- `model: kimi-code-plan-global/k3-256k` и `KIMI_API_KEY: ${{ secrets.KIMI_API_KEY }}` только в `env` шага OpenCode;
- явно `mentions: /opencode,/oc` и `share: false`, чтобы сессии из публичного репозитория не публиковались.

Checkout вместе с кодом перенесёт на чистый раннер `.agents/skills/`, `docs/agents/` и `AGENTS.md`; отдельные шаги копирования или установки скиллов не добавлять.

### 3. Дополнить корневой `README.md`

Добавить раздел **«OpenCode в GitHub Actions»** с указанием:
- назначения воркфлоу и пути `.github/workflows/opencode.yml`;
- двух событий и фильтра `created`, команд `/opencode` и `/oc`, ограничения на доверенных авторов;
- модели `kimi-code-plan-global/k3-256k` и имени секрета `KIMI_API_KEY` без значения;
- стандартной авторизации через OpenCode App, `share: false`, тайм-аута и concurrency;
- места просмотра результата: ответ агента в обсуждении issue/PR и запуск на вкладке **Actions**;
- управления запусками: **Cancel workflow** останавливает текущий прогон, **Disable workflow** запрещает новые запуски до повторного включения.

`AGENTS.md` оставить без изменений: его команды запуска, тестов, линтера и форматирования актуальны. `.github/workflows/hexlet-check.yml` не трогать.

### 4. Оформить и влить изменение

- Проверить diff и выполнить обязательный `mise run check`.
- Создать PR с коммитом по Conventional Commits и ссылкой на соответствующий issue; дождаться CI, проверить события, права, модель и отсутствие секретов в diff, затем влить в `main`.

## Verification

1. Создать тестовый issue для проверки интеграции.
2. Запустить командой `/oc` достаточно содержательный разбор issue и во время выполнения открыть **Actions → opencode → текущий запуск → Cancel workflow**. Убедиться, что запуск получил статус `cancelled`. Учесть, что уже отправленный запрос к Kimi может ещё некоторое время выполняться по правилам провайдера.
3. В **Actions → opencode** выбрать **Disable workflow**, оставить комментарий `/oc explain this issue` и убедиться, что новый запуск не появляется. Затем выбрать **Enable workflow**, чтобы восстановить интеграцию.
4. Повторно оставить `/oc explain this issue`; убедиться, что появился новый запуск `opencode`, он завершился успешно, а ответ от OpenCode App появился в issue.
5. Отдельной командой `/oc` попросить прочитать `AGENTS.md` и `docs/agents/`, назвать трекер, доступные скиллы `to-spec`, `to-tickets`, `implement-spec` и команду полной проверки. Ожидаемый ответ: GitHub Issues, все три скилла доступны, команда — `mise run check`.
6. Попросить OpenCode проверить и при необходимости дополнить описание воркфлоу в `README.md`; если агент создаст PR с уточнением, проверить и влить его. Это дополнительно подтвердит права GitHub App на изменение PR.
7. Добавить обычный комментарий без `/oc` и `/opencode` и убедиться, что новый запуск не появляется. Фильтры ботов, доверенных авторов, оба `types: [created]`, отсутствие `pull_request_target` и минимальные права дополнительно сверить с итоговым YAML.
8. Итоговые критерии: воркфлоу находится в `main` и включён, секрет хранится только в GitHub Secrets, свежий раннер видит проектные скиллы и настройки трекера, отменённый запуск и успешный финальный запуск видны в **Actions**, ответ агента доступен в issue.

## Assumptions

- Выбран стандартный OpenCode App, а не альтернативная авторизация; это соответствует заданию и требует только `contents: read` + `id-token: write`.
- По выбору пользователя используется подписка Kimi Code международного региона: провайдер `kimi-code-plan-global`, модель `k3-256k`, секрет `KIMI_API_KEY`. Тариф должен быть Plus/Moderato или выше; перед merge пользователь подтверждает, что его тариф поддерживает `k3-256k`.
- Для публичного репозитория публикация сессий отключена (`share: false`).
- Доверенные авторы — `OWNER`, `MEMBER`, `COLLABORATOR`; остальные комментарии и комментарии ботов игнорируются.
- Установка приложения, создание секрета, merge PR и отправка проверочных комментариев требуют действий пользователя в GitHub и не выполняются локальным агентом без подтверждения.
