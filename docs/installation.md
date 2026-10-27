# Установка blocky R6 / layout 7

1. Откройте server/funcombat_server.rbxl в Roblox Studio и опубликуйте весь плейс.
2. В Avatar Settings проверьте R6; в сохранённом файле уже включены native
   appearance, dynamic heads и MeshPart-heads, отключены Avatar Unification
   и upgrade-joints для совместимости исходных Motor6D-анимаций.
3. При обычном входе игрок появляется в закрытой комнате с полом, без подсказок.
   Loader скачивает видимую карту из GitHub. После полного успешного запуска
   сервер переносит игрока на исходный спавн карты.
4. На клиенте с loader видны только игроки с готовой картой. После респавна
   участие сохраняется. При смене карты, ошибке загрузки или выгрузке loader
   игрок возвращается в комнату до следующего успешного подключения.

В RBXL сохранены невидимые исходные коллизии и триггеры карты для общей физики.
Видимые карты лежат в `assets/world/*.rbxm`; код морфов этим обновлением не менялся.

Для публикации готового файла с телефона см. [инструкцию GitHub Actions](mobile-publishing.md).
Если старая копия не открывается с ошибкой `BodyTypeScale / Unexpected format 5`,
скачайте текущий `server/funcombat_server.rbxl`: см. [исправление формата](rbxl-format-fix.md).
Пустота при запуске прежней сборки также связана с потерянными флагами служб:
см. [исправление служб Studio](studio-service-fix.md) и скачайте обновлённый RBXL.
Ошибка `Model.PrimaryPart / Expected BasePart got Workspace` исправлена
в текущем файле: см. [исправление ссылок](studio-reference-fix.md).
Ошибка `DM contains duplicate Unique ids` также исправлена в текущем файле:
см. [исправление идентификаторов](studio-unique-id-fix.md).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader.lua?t=" .. tostring(os.time())))()
```

Обновление репозитория само по себе не меняет опубликованный плейс и старую
серверную сессию. Не смешивайте прежний .rbxl с новым client: loader проверяет
buildId из manifest.json и config/protocol.json.

Нужны HTTP GET, loadstring, writefile, getcustomasset/getsynasset и настоящий
локальный импорт RBXMX/RBXM через getobjects/Game:GetObjects. Native packages
сохраняют исходные MeshPart/UnionOperation/SurfaceAppearance. Карты загружаются
по необходимости; все карты сразу не прогреваются. Поддержка конкретного
executor и физика в настоящем сервере Roblox здесь не проверялись.

Владелец настроен в config/admin.json: 11556197791. Команды spawn, :dummy,
:spawndummy и :dummy 11556197791 создают серверных combat NPC; обычный Kohl
:clone me не регистрирует их в combat. Для dummy действует cooldown 3 секунды,
лимиты 4 на владельца и 20 на сервер. Hosted Kohl asset 1868400649 требует
доступности и разрешений Roblox.

Диагностика запускается отдельно через diagnose.lua или diagnose_dummy.lua.
Статические проверки и ограничения приведены в Validation_Report.md.

## Пересборка имеющегося сервера

Нужны Python, зависимости Builder/requirements.txt и rbxmk 0.9.1.
Для этой сборки нужен сохранённый сервер layout 6 до переноса карты.
Не подавайте текущий layout 7 повторно: его видимая геометрия уже скрыта.

```bash
python3 Builder/client_world_upgrade.py --source /path/to/layout6-baseline.rbxl --repo . --output dist/client-world --rbxmk /absolute/path/to/rbxmk
```

Она обновляет server/funcombat_server.rbxl, native-модели карт, config,
manifest и Client_World_Checks.json. До публикации запустите офлайн
проверки и сохраните единый согласованный commit. Не меняйте client-файлы
после запечатывания manifest без повторного обновления его контрольных сумм.

Для полной сборки из оригинального FunCombat_Renamed2.rbxl с прежним
проверенным checksum используйте Builder/build.py --source PATH --rbxmk PATH
--output dist/full. Недоступное вложение FunCombat_Renamed.rbxl не подменяется
старым оригиналом и не считается проверенным этим checksum.

Проверка Python: FUNCOMBAT_LUAU=/path/to/luau python3 -m unittest discover -s
Builder/tests -p 'test_*.py'. Runtime suites: Builder/tests/run_*.py --luau PATH.
Перед выпуском проверьте в Studio два клиента, поздний вход, R6-морф,
смену частей тела, одежду, dynamic head/face/mood, carry/drop, оружие и voting.
