# Установка blocky R6 / layout 6

1. Откройте server/funcombat_server.rbxl в Roblox Studio и опубликуйте весь плейс.
2. В Avatar Settings проверьте R6; в сохранённом файле уже включены native
   appearance, dynamic heads и MeshPart-heads, отключены Avatar Unification
   и upgrade-joints для совместимости исходных Motor6D-анимаций.
3. Зайдите в новый сервер. Каждый клиент запускает loader.lua из этого
   репозитория. Обычные имена и presentation восстанавливаются на этом клиенте.

Для публикации готового файла с телефона см. [инструкцию GitHub Actions](mobile-publishing.md).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader.lua?t=" .. tostring(os.time())))()
```

Обновление репозитория само по себе не меняет опубликованный плейс и старую
серверную сессию. Не смешивайте прежний .rbxl с новым client: loader проверяет
buildId из manifest.json и config/protocol.json.

Нужны HTTP GET, loadstring, writefile, getcustomasset/getsynasset и настоящий
локальный импорт RBXMX через getobjects/Game:GetObjects. 6 native packages
сохраняют исходные MeshPart/UnionOperation/SurfaceAppearance; 123 остальных
восстанавливаются из typed data. Поддержка конкретного executor не проверялась.

Владелец настроен в config/admin.json: 11556197791. Команды spawn, :dummy,
:spawndummy и :dummy 11556197791 создают серверных combat NPC; обычный Kohl
:clone me не регистрирует их в combat. Для dummy действует cooldown 3 секунды,
лимиты 4 на владельца и 20 на сервер. Hosted Kohl asset 1868400649 требует
доступности и разрешений Roblox.

Диагностика запускается отдельно через diagnose.lua или diagnose_dummy.lua.
Статические проверки и ограничения приведены в Validation_Report.md.

## Пересборка имеющегося сервера

Нужны Python, зависимости Builder/requirements.txt и rbxmk 0.9.1.
Команда проверяет совпадение исходного сервера и конфигурации репозитория:

```bash
python3 Builder/native_r6_upgrade.py --source server/funcombat_server.rbxl --repo . --output dist/native-r6 --rbxmk /absolute/path/to/rbxmk
```

Она обновляет server/funcombat_server.rbxl, config и manifest, а также пишет
binary/XML и Native_R6_Checks.json в output. До публикации запустите офлайн
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
