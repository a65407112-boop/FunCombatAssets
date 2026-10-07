# Отчёт проверки — 7 октября 2026

Источник: предоставленный `FunCombat_Renamed2.rbxl`, SHA256 `a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0`. Builder сохраняет исходник нетронутым. Геометрия моделей, mesh, карты и визуальное сходство не инспектировались по просьбе пользователя.

## PC Maxwell, исходный MeshPart и крепление костюмов

Пользователь сообщил, что предыдущий loader работал на телефоне, но на ПК падал при warm-up weapons/Maxwell: `SurfaceAppearance can only be parented to MeshParts`. Также сообщены огромные Sword/Maxwell, невидимый female torso и увеличенный male torso. Эти наблюдения относятся к предыдущей сборке.

Точный PC fatal воспроизведён через настоящий assets factory с API double: запись MeshPart.MeshId запрещена, а SurfaceAppearance можно parent только в MeshPart. Прежний fallback создавал Part/SpecialMesh; сохранённый SurfaceAppearance затем получал несовместимого родителя. Writable MeshId на телефоне обходил этот fatal, но не доказывал сохранение native initialization/InitialSize оригинального MeshPart. Размеры не исправлялись произвольными множителями.

Builder теперь переносит 11 оригинальных leaf MeshPart и один SurfaceAppearance как минимальные encoded native-зависимости в ReplicatedStorage. Все их сериализованные свойства, opaque load state и используемые SharedStrings сохраняются; SurfaceAppearance хранится под оригинальным MeshPart с исходным processed TexturePack. Полные weapon/costume hierarchies остаются во внешнем пакете. Factory клонирует настоящие объекты, очищает template children и восстанавливает JSON parents/references; PBR child создаётся ровно один раз. Защищённые MeshId/MeshContent/InitialSize и PBR maps/pack не перезаписываются. Writable исходные Size/CFrame/TextureID/RenderFidelity продолжают применяться. Изменений source mesh/texture IDs, масштабов модели или геометрической инспекции нет.

Полные LowerRig/TorsoRig, Sword и Maxwell проходят constructor/member/ref tests. Строгий PC double и writable phone double оба сохраняют native metadata; оригинальный SurfaceAppearance остаётся у реального MeshPart. Отсутствующая native mesh dependency завершается с encoded path и deadline. Статика сравнивает оригинальные сериализованные свойства с сохранёнными leaf dependencies как непрозрачные данные.

В Pair найдено отдельное отличие от source NewChanger: прежний код перемещал только ref до parenting костюма, когда его WeldConstraint ещё не активны. Эта запись удалена. Clone входит в персонажа с исходными part frames, затем identity torso-to-ref weld крепит его как в оригинале. Новые проверки авторских ref-relative CFrame наблюдались RED→GREEN для обоих костюмов. Проверка visibility/Size/SpecialMesh.Scale/Motor offsets проходила и до изменения; удвоение male torso не воспроизведено и его причина этим тестом не доказана.

Это исправление конкретных путей реконструкции, а не подтверждение нового рендера. Roblox Studio/движок/настоящий executor отсутствуют. Видимость female torso, размеры Sword/Maxwell/male torso, hosted PBR и совместимость конкретного старого клиента после нового build требуют пользовательского playtest. Требуется публикация нового серверного файла целиком: одна правка GitHub не добавляет native dependencies.

## Сохранённое исправление WeldConstraint

Пользователь передал полный fatal error: `costumes/TorsoRig reference Part0Internal: Part0Internal is not a valid member of WeldConstraint`. Этот отказ воспроизведён через реальный assets factory со строгим WeldConstraint double; прежний generic mock ошибочно разрешал запись любых имён членов.

Roblox публично предоставляет `WeldConstraint.Part0` и `Part1`. Исходный XML использует внутренние сериализованные `Part0Internal` и `Part1Internal`; они не являются доступными runtime members. Source exporter теперь нормализует только эти имена в JSON для класса WeldConstraint. Assets factory понимает также прежние JSON через class-specific aliases. Исходные цели не удаляются и не подменяются: node7795 сохраняет Part0→7711 (`ref`) и Part1→7791 (`skinTorso`). Исходник и оригинальные model XML exports остаются прежними. Неизвестные nonempty refs продолжают останавливать загрузку с точной ошибкой.

Проверены оба полных оригинальных костюма — LowerRig (58 Instances) и TorsoRig (86 Instances): membership, все обязательные weld endpoints и оригинальные незаполненные Part0 у трёх attachment motors. Это реальный constructor с заменой engine APIs, без проверки geometry, рендера или физики. Все 129 пакетов дополнительно проходят статическую проверку и не имеют незамкнутых refs или внутренних WeldConstraint member names в runtime JSON.

Три original UnionOperation по-прежнему остаются минимальными native replicated dependencies. Клиент клонирует их непрозрачные оригинальные CSG-данные и восстанавливает остальные Instances/properties/refs извне. Local GetObjects для исходных костюмов не нужен. Opaque payload bytes и membership сравниваются без разбора геометрии.

## Владелец и dummy

Пользователь явно указал настоящий numeric UserId **11556197791**. Единственный исходный параметр хранится в `config/admin.json`; builder проверяет positive exact integer, включает его в серверный `Config.ownerUserId` и добавляет тот же ID в оригинальный Kohl Owners. Старые usernames и first joiner не используются. Client не может назначить owner запросом или локальной правкой config: сервер использует свой скомпилированный Config.

AdminAccess немедленно разрешает этому реальному Player game controls, сохраняя отдельную автоматическую проверку настоящего опубликованного CreatorId/CreatorType и GroupService.Owner.Id. Group error/timeout не отменяет явный grant и не разрешает посторонних. Отсутствующий/некорректный configured ID не даёт grant; departed/spoofed/destroyed identities закрыты. Attributes `FunCombatAdminAllowed`, `FunCombatAdminSource`, `FunCombatConfiguredOwnerUserId`, creator state/errors показывают фактический результат. Смена аватара или username не меняет numeric ID.

Оригинальный Kohl’s Admin Infinite запускается через настоящий hosted module1868400649 и исходный native Credit/Settings/Custom Commands hierarchy с _G.KAU selector. Native Owners означает power5. `:dummy`/`:spawndummy [userId]` теперь доступен с Owner5, а server-only BindableFunction повторно проверяет AdminAccess и исходные игровые ограничения. Settings wrapper сохраняет все исходные настройки и остальные role lists, добавляет владельца без дубликата, не меняя source DOM.

`:dummy` создаёт исходный боевой DummyRig перед игроком; `:dummy 11556197791` использует внешний вид указанного ID через настоящий Avatar path. Требуются живой свободный персонаж, разрешённый AllowDummys; cooldown3 секунды, 4 dummy на игрока, 20 на сервер. Dummy регистрируется в реальном combat. Встроенная game panel тоже использует серверную проверку.

Пользователь сообщил, что Kohl UI уже появился в предыдущем server build; UI само по себе не подтверждает native rank. Новая явная Owners конфигурация проверена в Luau офлайн, live grant после публикации пока не подтверждён. Hosted KAI может обновляться независимо от GitHub; его исходные creator/role rules и runtime UI/scripts/remotes сохранены. Upstream reference commit `31cbe8ad97e920ff8476eeca6e9aa2f206f8fdf1` и Roblox metadata подтверждают module1868400649. Полный hosted модуль не vendored в архив. Native require мониторится 20 секунд и не блокирует combat; уже начатый engine require нельзя отменить.

## Голова и отдельная диагностика

Причина чёрного рендера в игре пока не установлена. Без actual engine state менять Head.Color, Material, текстуры или оригинальный ресурс по предположению нельзя. Прежний avatar adapter сохраняет настоящие Head/Face/HeadColor/Mood IDs, FaceControls/Bones и original PBR; при необходимости переносит только настоящий head из временного R15 donor на исходное R6-тело. Original avatar body parts заменяются исходным combat R6, dynamic head не создаётся из придуманных данных.

Official Roblox Users API подтвердил ID11556197791 как TodUntitled. Snapshot Avatar/Wearing от **2026-10-06T14:48:19Z** содержит R6, headColorId1001 (Institutional white), dynamic-head ID89515250410521 (`Cute Kawaii Chibi Face - Dynamic Head`) и MoodAnimation14618207727 (`Default Mood`). Официальная неизменённая headshot thumbnail имеет Completed и отображает светлую голову. Это metadata/2D preview конкретного момента; пользователь может сменить аватар. Это не подтверждает корректность этого head в настоящем combat server.

После fatal bootstrap cleanup останавливал дальнейшие callbacks avatar_content. Поэтому полезные ошибки головы могли отсутствовать после падения на TorsoRig; это не доказательство причины чёрного цвета. Существующий content watcher подготавливает actual head/accessory/mood по мере репликации, ограничивает native calls/deadlines и сохраняет server warning для позднего клиента. SurfaceAppearance processed packs не подтверждаются PreloadAsync.

По отдельному явному требованию пользователя добавлен самостоятельный **diagnose.lua**, запускаемый вручную и не вызываемый основным loader. Он не зависит от живого runtime/ctx и работает после failed bootstrap. Читает текущие head/face/PBR references/colors, actual content status и доступные ошибки, CreatorId/Type, numeric local ID, server grant attrs и native Kohl rank. Никакого переодевания, исправления цвета, сети, исследования геометрии или бесконечных ожиданий. Повторный ручной запуск снимает актуальные данные после смены аватара/respawn. Старые API отсутствуют — это явно записывается, а не предполагается modern compatibility.

Обновление standalone diagnostics после пользовательского сообщения «всё работает, кроме чёрной головы»: отчёт показывается в отдельном ScreenGui с прокруткой, selectable TextBox, Copy report и Close. Console access не требуется. Copy использует доступный clipboard API; отказ отображает точную причину и даёт manual select-all. Редактирование display text не меняет копируемый исходный snapshot. Повторный запуск удаляет только предыдущий diagnostic GUI. Parent fallback: PlayerGui, доступный gethui, CoreGui. Изменений персонажа, сети, протокола, gameplay loader и server build ID нет. 13 actual diagnostic chunk scenarios прошли офлайн, включая прежние 8 проверок чтения данных и 5 UI/copy/cleanup случаев; UI отсутствие наблюдалось RED перед внедрением. Показ GUI и системный clipboard настоящего executor здесь не тестировались.

## Состав и авторитетность

Исходные окружение, Crossroads/BackStreet, спавны, физика и необходимые серверные зависимости остаются в плейсе. Внешний пакет содержит 129 original packages, 47 KeyframeSequences, шесть исходных оружий, LowerRig/TorsoRig, original GUI/audio/effects и исходные Roblox references. Не придуманы ресурсы или working URLs. Prompt positions/keys/distances/hold conditions сохраняются, labels/network IDs кодируются и восстанавливаются внешним manifest; обязательные engine/body names не переименованы.

Policy/CombatServer проверяют intentions, distances, character/target state, ownership, rate limits, cooldown и удержание. Сервер определяет damage/hits/kills, ragdoll/recovery/carry, executions, paired stages/meter/Completions, voting/weather и общие результаты. Server events/snapshot синхронизируют clients и late joins; local effects не названы автоматически реплицированными. Respawn/exit завершают активное взаимодействие. Encoding не является авторизацией.

Сохранены прежние fixes: original map fallback, safe spawn до yielding appearance, bounded CharacterAdded parenting и освобождение root; исходный R6 Tool.Grip, gait при upper-body animation; carry network/controller cleanup; female TorsoRig role/interaction-ID и bounded effects. Пользователь подтвердил original map restoration в более раннем build. Новая сборка не получила live подтверждения.

## Выполненные проверки

Реальные Lua modules/factories выполняются с заменой только engine/executor APIs:

- 35 admin scenarios: explicit ID выше32bit, actual creator/group owner, original pending/error/timeout, malformed config, early joins, exact Player lifecycle, реальные CombatServer intents/snapshot, genuine hosted loader и server dummy bridge/game rules.
- 3 native Kohl settings scenarios исполняют обёртку builder над настоящим исходным Settings6658: настройки и другие role lists сохранены, ID добавлен, дубликат не возникает.
- 14 native assets scenarios: строгая граница WeldConstraint и MeshPart/PBR, readonly PC и writable phone doubles, original native metadata, exact source endpoints, полные LowerRig/TorsoRig/Sword/Maxwell, original CSG, missing/wrong native dependency и deadline; пользовательский mesh/PBR import выбирает существующий model backend, в том числе при совпадении source IDs, а оригинальные unmapped assets не получают silent fallback.
- 10 avatar content, 9 avatar adapter, 4 real-loader bootstrap, 12 presentation, 5 carry, 9 morph/effect (включая авторские offsets и исходные visibility/Size/Scale/Motor properties), 16 spawn/map; server lifecycle, client networking/state/diagnostics, Policy.
- 15 builder и 14 outfit importer Python tests. Native mesh migration, exact PC parent fatal и costume mount offsets наблюдались RED→GREEN.
- Separate diagnostic scenarios и их фактическое число записаны в Release_Checks.json.

Static_Checks.json проверяет source checksum, manifest SHA256/Adler32/bytes, dependency DAG, XML referents/shared strings, protocol/build identity, три combat network templates, original prompt templates, package hierarchy/references, native union opaque fidelity, все сериализованные original MeshPart/PBR properties и PBR parent, настоящий Kohl hierarchy, единственный configured numeric ID в server/native settings, binary header/property types и safe R6/original map spawns.

Release_Checks.json содержит actual compile counts, rbxl→rbxlx codec roundtrip (server script sources byte equivalent), повторную byte-identical сборку, hashes и реальные HTTP/raw GitHub deployment checks. Это CLI/static/mock проверки, а не Roblox playtest. Источники Roblox API: [MeshPart](https://create.roblox.com/docs/reference/engine/classes/MeshPart), [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance), [WeldConstraint](https://create.roblox.com/docs/reference/engine/classes/WeldConstraint), первичная reflection serialization [rojo-rbx/rbx-dom](https://github.com/rojo-rbx/rbx-dom). Metadata аватара — official Roblox Avatar/Users/Economy/Thumbnails API.

## Непроверено или отсутствует

- Roblox Studio/движок/executor недоступны: live импорт/публикация, два клиента, physics, controls, head rendering, настоящие asset permissions здесь не проверены. Офлайн GREEN не означает полную рабочую копию Roblox.
- Чёрная голова не воспроизведена в движке. Исправлены конкретный fatal weld и owner config; динамический face/render success не заявляется. Separate diagnose — способ получить фактические данные, а не исправление рендера.
- Genuine hosted Kohl require/version/rank и hosted mesh/texture/audio/animation разрешения не engine-tested. User UI observation относится к предыдущей сборке; explicit Owners5 новый grant требует проверки в новом сервере.
- Adonis не активирован; исходник сохранён в source/external. Отсутствующий original server handler Microphone/TransmitBaseEvent не придуман. Additional custom outfit packages не предоставлены; исходные LowerRig/TorsoRig присутствуют.
- Небезопасный Part/SpecialMesh fallback для MeshPart удалён. Исходные 11 MeshPart и PBR используют native clones; actual engine initialization/render после этого изменения не подтверждены. User-created costume с MeshPart/PBR загружает исходный `.rbxmx` через существующий bounded local model backend; поддержка этого backend настоящим executor здесь не проверена. Other unmapped original JSON assets завершаются с точной ошибкой. Optional unsupported class/property failures сообщаются.
- Конкретный старый Roblox-клиент/executor не подтверждён. Дополнительные model packages без native dependencies могут требовать local rbxmx backend.
- Roblox place не опубликован в аккаунт пользователя. Для проверки нужен новый серверный rbxl целиком, публикация и новый server session с совпадающим build ID; одной правки GitHub недостаточно.

Полная копия, визуальная идентичность и успешный engine playtest не заявляются.


## Живой отчёт головы и отдельное сравнение 7 октября

Пользователь сообщил, что остальная игра после предыдущего обновления работает, и прислал head report 2026-10-07T13:53:24Z плюс скриншот чёрного лица. Runtime initialized, protocol 4/build6a27795e99d5b46ef4847aec, R6; Head — MeshPart с FaceControls, почти белым Color и оригинальными mesh77342075522894/texture130652123696339. Content fetch Success не подтверждает рендер. Creator/server grant и native Kohl entry11556197791:7/power7 подтверждены именно этим живым отчётом.

Из официального assetdelivery извлечена неизменённая RGBA PNG130652123696339 (512×512); прозрачный фон имеет чёрные RGB. Внешний JSON хранит точные пиксели, PNG/RGBA SHA256; decoder проверяет полную длину и исходный Adler32. Никакая геометрия не исследовалась. Отдельный head_test.lua создаёт временный native EditableImage/SurfaceAppearance Overlay после Test texture, сохраняет original Head.Color/TextureID/MeshId/FaceControls/joints, содержит Restore/Close/Copy report, bounded HTTP/native calls, очистку поздних результатов, повторного запуска, удаления персонажа и смены Player.Character. Он не встроен в loader, не меняет protocol/build ID, не требует перепубликации сервера.

Статические/офлайн проверки: 4 exporter-теста (включая точный RGBA roundtrip и сохранение исходника), 15 Luau-сценариев (успех, ошибочный source, malformed data, отсутствующий API, network/native failure, timeout, отмена после принятого результата, изменение texture во время native обработки, Restore/rerun/respawn). API doubles не подтверждают рендер; доступность EditableImage/SurfaceAppearance на устройстве пользователя неизвестна. Визуальный результат записывается только как ответ пользователя. Инструкция: docs/head-test.md.

Подтверждена отдельная ошибка facial mood: каталог14618207727 — пакет Default Mood/type78 с Animation1→14618196485 (EmptyDefaultMood/type24, без Keyframe); текущий characters.lua передаёт wrapper ID непосредственно в LoadAnimation. Это объясняет invalid AnimationClip. Постоянное изменение mood пока не опубликовано: тест сравнивает только обработку alpha оригинальной текстуры. Чёрный рендер и правильность выражения лица в Roblox ещё не исправлены/не подтверждены.
