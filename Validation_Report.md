# Отчёт проверки — 6 октября 2026

Сборка основана только на предоставленном `FunCombat_Renamed2.rbxl`, SHA256 `a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0`. Исходник остаётся нетронутым. Геометрия моделей, mesh, карты и визуальное сходство не инспектировались по просьбе пользователя.

## Подтверждённые ошибки и изменения

**Bootstrap.** Воспроизведён отказ реального assets factory при отсутствии local executor model deserialization. Два исходных costume-пакета содержат три встроенных UnionOperation, которые нельзя создать через Instance.new с теми же CSG-данными. Builder сохраняет ровно эти три native зависимости; внешние JSON описывают оригинальные Instances, properties, children и internal refs. Клиент клонирует непрозрачные original unions и восстанавливает исходные descendants из JSON. Local GetObjects для этой сборки больше не обязателен. Исходные rbxmx сохранены как дополнительные exports/fallback, не названы самостоятельным загрузчиком. Сравниваются opaque payload bytes и membership, геометрические данные не разбираются.

**Ошибки loader.** Реальный loader протестирован с HTTP/UI doubles: полный suffix resource failure виден и копируется; pre-manifest HTTP failure не требует скачанного UI; повторный запуск заменяет окно, успешный запуск удаляет его. Runtime destruction остаётся idempotent. Консоль сохраняет точную первичную ошибку.

**Голова.** Screenshot в текущем сообщении показывает только обрезанную ошибку preload, а не внешний вид головы. Поэтому причина чёрного рендера не установлена. Воспроизведены отдельные ошибки загрузки/диагностики: ранний Error терялся до listeners/snapshot activation, а original preloader не готовил фактический server-loaded head/accessories/mood. Добавлен watcher реальных ресурсов по мере репликации и их изменения. На персонажа допускается один native preload; timeout прекращает монитор, поздние engine callbacks отменённого персонажа игнорируются. FunCombatAvatarDiagnostic сохраняет точную server warning для позднего клиента. Original head Color/Material/TextureID, SurfaceAppearance maps, FaceControls/Bones и donor logic не заменены. SurfaceAppearance packs не подтверждаются PreloadAsync; их streaming остаётся задачей Roblox. Это исправление подтверждённых code paths, а не подтверждение визуального исправления в игре.

**Админ.** Ранее Kohl’s был выключен; game panel использовала старые usernames. Теперь panel и native dummy bridge авторизуются через опубликованные CreatorType/CreatorId и GroupService.Owner.Id. User creator назначается сразу; group lookup ограничен 10 секундами; ранние joins обновляются; malformed response, timeout, departed/spoofed players fail closed. Legacy usernames, first joiner и private server host не дают прав этим game controls. Every action проверяется сервером.

KohlAdmin запускает настоящее require(1868400649) с native original Credit Script и оригинальными Settings/Custom Commands. Credit оставлен Disabled, чтобы wrapper выполнял старт один раз. Original custom examples сохранены; добавлены :dummy/:spawndummy [userId]. Command вызывает server-only BindableFunction, который проверяет owner/ID и оригинальный World:dummy. DummyRig, R6 appearance, spawn перед игроком и combat registration реальны; лимиты 3 секунды, 4 на игрока, 20 на сервер и AllowDummys/free-state сохраняются. Hosted Kohl сохраняет upstream creator/role policy, включая собственное поведение Studio/private servers; наша fail-closed политика касается panel и dummy bridge.

Official upstream loader и Roblox metadata подтверждают module1868400649 как Kohl MainModule; upstream reference commit `31cbe8ad97e920ff8476eeca6e9aa2f206f8fdf1`. Исходная hosted версия не содержится в плейсе и не vendored в архив. Kohl создаёт собственные native UI, LocalScripts и remotes во время выполнения. Ошибка/timeout hosted require сообщается через Output и client admin status; монитор ограничен 20 секундами и не блокирует combat. In-flight Roblox require нельзя отменить: запоздалые внутренние эффекты внешнего модуля возможны. Live permission/creator grant здесь не проверен.

## Состав и серверная авторитетность

Оригинальные окружение, Crossroads/BackStreet, спавны, физика и server dependencies остаются в плейсе. Внешний пакет содержит 129 original packages, 47 KeyframeSequences, шесть исходных оружий, LowerRig/TorsoRig, GUI, audio/effects и оригинальные Roblox mesh/texture/sound/animation references. Snapshot/events восстанавливают состояние позднего клиента; respawn/exit завершают активные взаимодействия. Network identifiers и prompt labels закодированы; внешний manifest восстанавливает подписи, исходные engine/body names сохраняются.

Policy/CombatServer проверяют намерения, distances, character/target state, ownership, rate limits, cooldown и hold. Сервер определяет урон, попадания, kills, ragdoll/recovery/carry, executions, pair stages/meter/Completions, voting/weather и общие результаты. Внешние local effects не считаются автоматически реплицированными: сервер broadcast/snapshot задаёт общий результат. Identifier encoding не является средством авторизации.

Предыдущие fixes сохранены: map fallback из оригинального ServerStorage template; safe spawn до yielding appearance; CharacterAdded ожидает parenting и освобождает root; original R6 Tool.Grip поворот; gait при upper-body poses; native carry ownership/controller cleanup; female TorsoRig role/pair-ID handling и bounded effect queue. Пользователь подтвердил map restoration в более раннем build; другие симптомы и текущая сборка не получили live подтверждения.

## Свежие проверки

Все следующие проверки исполняют реальные modules/factories с заменой только Roblox/executor APIs:

- 25 admin cases: user/group creator, fail-closed malformed/error/timeout, early joins, реальный CombatServer panel/snapshot, original hosted loader/deadline/duplicate reservation, owner-only native command, actual World/Avatar/combat dummy registration, ID validation, cooldown/limits/config/state.
- 10 avatar content, 9 avatar adapter: actual head/accessory/mood refs, late Head, changes, respawn/exit, exact hosted failures, stalled request bounds, original appearance preservation, late diagnostic recovery, state-fed dummy cleanup.
- 4 native CSG cases и 4 real-loader bootstrap cases: original payload/children/internal weld refs, no local deserializer, missing/wrong native dependency, full error/copy, HTTP failure, reexecution.
- 12 presentation, 5 carry, 6 morph/effect, 16 spawn/map cases; server lifecycle, client network/state/diagnostics, Policy.
- 11 builder и 13 outfit importer Python unit tests.

Static_Checks.json проверяет source SHA, manifest SHA256/Adler32/bytes, dependency DAG, XML referents/shared strings, exact protocol/build IDs, три combat remote templates, native prompt templates, all external hierarchy/internal refs, original opaque union dependency membership, original Kohl hierarchy, binary header/type IDs и safe R6/active original spawn setup. Новые hosted Kohl remotes создаются только runtime и в эти три combat templates не входят.

Release_Checks.json фиксирует фактические числа compile checks, binary rbxl→rbxlx roundtrip (источники скриптов byte equivalent, links/shared payloads), повторную deterministic сборку и настоящие raw GitHub URL/manifest hashes. Это codec/CLI/mock checks, не playtest Roblox. Builder воспроизводим при тех же source/repository/rbxmk; hosted version/content на Roblox независимо изменяемы.

## Непроверено или отсутствует

- Roblox Studio/движок/executor недоступны: импорт/публикация, два live клиента, physics, controls, rendering/head shading, real respawn/exit и hosted content permissions здесь не проверены. Офлайн GREEN не означает полную рабочую копию в Roblox.
- Чёрный рендер головы не воспроизведён. Нельзя подтвердить, что дополнительные preload/diagnostics исправили его. Dynamic heads/mood зависят от настоящих avatar assets и engine API; legacy fallback не гарантирует dynamic face.
- Hosted mesh/texture/audio/animation и Kohl permissions/version недоступны для engine проверки. module1868400649 проверен по официальному source/metadata, но authenticated binary download и фактический require здесь не выполнены.
- Adonis не подключён; original loader/settings сохранены в source/external. Не придумана механика Microphone/TransmitBaseEvent без original server handler; obsolete orphan network удалена. Additional custom outfit packages в config/outfits не предоставлены; доступны исходные LowerRig/TorsoRig.
- Client MeshPart fallback при невозможности установки MeshId использует исходные IDs через SpecialMesh и не воспроизводит PBR SurfaceAppearance. Unsupported optional properties/classes выводятся как предупреждения. Native avatar head и три native unions этим substitute fallback не заменяются.
- Поддержка конкретного старого Roblox-клиента и executor не подтверждена. Для дополнительных model packages без native dependencies требуется поддерживаемый local rbxmx backend; никакой working backend не выдуман.
- Публикация Roblox-сервера в аккаунт пользователя не выполнялась. Для теста нужно опубликовать новый .rbxl и зайти в новый server; одного GitHub update недостаточно.

Полная копия игры, визуальная идентичность и успешный Roblox playtest **не заявляются**.
