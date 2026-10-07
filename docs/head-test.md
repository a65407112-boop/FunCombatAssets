# Отдельный тест чёрного лица

`head_test.lua` — вручную запускаемое сравнение, не автоматическое исправление
и не часть обычного loader. Новый серверный плейс для него не требуется.

В присланном отчёте от 2026-10-07T13:53:24Z настоящая динамическая голова
89515250410521 имеет `FaceControls`, MeshPart и светлый `Head.Color`.
Mesh 77342075522894 и texture 130652123696339 соответствуют реальному пакету
головы. Исходная PNG-текстура RGBA имеет прозрачный фон с чёрными RGB-пикселями.
На присланном скриншоте фон лица чёрный. Поэтому проверяется гипотеза о потере
наложения цвета кожи при отображении текстуры на перенесённом R6 MeshPart.
Это гипотеза, а не подтверждённая причина рендера.

После обычного loader выполните:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/head_test.lua?t=" .. tostring(os.time())))()
```

1. Нажмите **Test texture**, посмотрите на лицо.
2. Выберите **Looks correct** или **Still wrong**, затем **Copy report**.
3. **Restore** возвращает прежний вид; **Close** также удаляет временный слой.

Консоль не нужна. Если clipboard недоступен, отчёт можно выделить и скопировать
вручную. Повторный запуск заменяет только окно и временный слой этого теста.
После удаления головы или смены персонажа ресурсы теста освобождаются; для
нового персонажа нужно запустить его снова.

Тест сохраняет исходные пиксели, включая прозрачные RGB и alpha, в EditableImage
и создаёт настоящий обработанный SurfaceAppearance через
`AssetService:CreateSurfaceAppearanceAsync`. `AlphaMode.Overlay` накладывает
исходное лицо поверх прежнего `Head.Color`. Head.Color, TextureID, MeshId,
FaceControls, суставы и анимации не изменяются. Геометрия не исследуется.
Результат создания Instances не объявляется подтверждением корректного рендера:
визуальный ответ пользователя хранится отдельно в отчёте.

Проверяется только исходная texture 130652123696339 из этого отчёта. Если аватар
сменился на другую текстуру или уже имеет SurfaceAppearance, тест сообщает
причину и сохраняет внешний вид. Владелец, репозиторий и ветка берутся из
активного `loader.lua` CONFIG; отдельной настройки репозитория нет.

Нужны современные `buffer`, `Content.fromObject`, `CreateEditableImage` и
`CreateSurfaceAppearanceAsync`. Их наличие проверяется. Доступ к EditableImage
может зависеть от настроек API игры и бюджета устройства. Отказ сообщается
прямо в окне; скрытые protected ColorMap-записи и заменители не используются.
HTTP ограничен 15 секундами, native processing — 10. Поздний native результат
после отмены/таймаута уничтожается и не устанавливается на голову.

# Источники и воспроизведение

- Оригинальный asset: `https://assetdelivery.roblox.com/v1/asset/?id=130652123696339`.
- PNG SHA256: `72bde92df1de980578edbb21f40858771ea7d4cb215a68cd24627d6e4b88e461`.
- RGBA SHA256: `cd67ba43010b8d05a72a95134620a7f7e829bbd67f535a58f7715fc7fdef9e1e`.
- RGBA: 512×512, 1048576 байт; Adler32 `4278240354`.
- [Roblox AlphaMode](https://create.roblox.com/docs/reference/engine/enums/AlphaMode).
- [Roblox SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance).
- [Roblox AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService).

Вспомогательный exporter требует Pillow и проверяет SHA оригинального ресурса:

```bash
python -m pip install Pillow
python Builder/export_head_texture.py --download
# Или: --source /absolute/path/to/the_original.png
python -m unittest Builder/tests/test_head_texture_export.py -v
python Builder/tests/run_head_texture_tests.py --luau /absolute/path/to/luau
```

Exporter не изменяет исходный PNG; JSON содержит серии точных RGBA-пикселей,
а не перекрашенную картинку. Основной builder копирует этот самостоятельный
тест вместе с репозиторием. Он не добавляет его в обычный client bootstrap.

Отдельно подтверждена ошибка текущего `client/characters.lua`: MoodAnimation
14618207727 — asset type 78, пакет `Default Mood`, а не Animation clip.
Внутри `R15Anim/mood/Animation1` находится ссылка 14618196485, asset type 24,
`EmptyDefaultMood`; его KeyframeSequence не содержит Keyframe. Прямая передача
14618207727 в LoadAnimation объясняет присланный `AnimationClip loaded is not
valid`. Этот тест анимации не меняет, связь ошибки mood с чёрным фоном не
подтверждена. Постоянное исправление головы и mood остаётся отдельной задачей
после проверки в Roblox.

Roblox Studio/движок/executor в среде разработки недоступны. Проверки exporter
и Luau подтверждают данные, ограничения и очистку; они не подтверждают рендер,
разрешения runtime API или поддержку старого Roblox-клиента.
