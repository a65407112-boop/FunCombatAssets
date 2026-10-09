# FunCombat — protocol 5

Новая поставка содержит исходные карты, физику, спавны, ProximityPrompt и авторитетную серверную логику. Вне карты/окружения сохранён один Model — StarterCharacter. Два разных исходных NPC-rig создаются из типизированных данных во время игры. Crossroads больше не дублируется; чистый шаблон создаётся до голосования.

129 оригинальных клиентских пакетов и 47 исходных анимаций находятся во внешнем пакете. Реплицируемые constructor-копии оружия/костюмов удалены. Шесть пакетов с MeshPart, UnionOperation или SurfaceAppearance импортируются из оригинальных RBXMX; остальные восстанавливаются из структурированных данных. Ссылки на mesh, texture, sound и animation сохраняются.

**Нужно опубликовать новый server/funcombat_server.rbxl целиком и войти в новый сервер.** Обновление GitHub не обновляет запущенную серверную сессию. Loader требует совпадающие protocol 5 и buildId; значение этой поставки находится в config/protocol.json и manifest.json.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader.lua?t=" .. tostring(os.time())))()
```

Нужны HTTP GET, loadstring, writefile, getcustomasset/getsynasset и настоящий импорт локального RBXMX через getobjects/Game:GetObjects. Loader проверяет возможности и импортирует оригинальные ресурсы до подключения игрового ввода. PC/телефон и конкретные executor здесь не проверены; отсутствие поддержки даёт конкретную ошибку с ограниченным ожиданием.

Исправлен воспроизведённый путь потери цветов тела: R6-нормализация сохраняет Color в BodyPartDescription вместо удаления этих объектов. Native dynamic head и отдельные цвета torso/конечностей сохраняются, в том числе у dummy по UserId. Чёрный popup при успешном spawn/dummy остаётся отключён. Проверки кода не подтверждают live рендер в Roblox.

Сохранённые неслужебные имена, подписи промптов, stats, игровые атрибуты и presentation IDs закодированы; внешний клиент восстанавливает понятные подписи. config/identifiers.json содержит публичные обратимые соответствия. Обязательные имена Roblox, leaderstats и совместимость Kohl Settings/Custom Commands сохранены. Это обфускация, а не секретное шифрование или гарантия модерации. Урон, дистанции, цели, cooldown и игровые результаты проверяет сервер.

Владелец 11556197791 задан в config/admin.json. Боевой NPC: **spawn**, **:dummy**, **:spawndummy** или **:dummy 11556197791**. Обычный **:clone me** из Kohl не регистрирует combat NPC. Условия и ограничения команд описаны в [инструкции](docs/installation.md).

Диагностика остаётся отдельным ручным скриптом с Copy report; основной loader её не запускает:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/diagnose.lua?t=" .. tostring(os.time())))()
```

Источник — FunCombat_Renamed2.rbxl, SHA256 a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0. Builder сохраняет исходник нетронутым. Геометрия не исследовалась по просьбе владельца. Полный архив содержит исходник, builder, серверные binary/XML-файлы, внешний репозиторий и документацию.

[Установка и пересборка](docs/installation.md), [состав механик](docs/restoration.md), [устройство](docs/architecture.md), [отчёт проверки](Validation_Report.md). Roblox Studio/engine, реальная игра с несколькими клиентами, рендер, hosted permissions и старые клиенты/Bloxstrap остаются непроверенными. Результаты офлайн-проверок записаны в Static_Checks.json и Release_Checks.json поставки. История старой компоновки находится в docs/history.
