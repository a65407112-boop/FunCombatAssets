# Изменения сборки

Добавлен воспроизводимый Builder из конкретного приложенного плейса. Результаты: funcombat_server.rbxl, Game_Server.rbxlx, Game_GitHub.zip, Game_ExecutorSide.zip и loader.lua. Исходный файл сохранён.

Полная серверная адаптация исходных механик находится в Builder/templates/server: бой, авторитетные попадания/урон, восстановление, перенос и исполнения, все исходные парные варианты, шкала/Completions, окружение, голосование, погода и R6 avatar normalization. Перенесены LowerRig/TorsoRig и все 47 последовательностей. Исходные данные и программы сохранены в source.

Клиент обновлён под encoded protocol 4 с точным build ID. Восстановление typed Instances/refs дополнено настоящим CSG deserialization. Добавлены bootstrap buffer, dependency traversal, manifest integrity, snapshots, respawn и cleanup повторного запуска.

Исправлен порядок спавна: исходное R6-тело удерживается на исходном спавне до нормализации внешности; защита шеи включена до ApplyDescription, параллельная engine appearance загрузка отключена. Dead/stale character не может завершить старую инициализацию. Пользовательское сообщение о смерти в пустоте — наблюдение из движка; новый фикс пока проверен офлайн.

Исправлена также обязательная загрузка карты: по предоставленному Studio stack World.new останавливался из-за отсутствия обнаруженного IsMap. Начальная карта теперь задаётся исходными данными, выбирается по точному имени и при необходимости восстанавливается из исходного ServerStorage-шаблона с ограниченным ожиданием. Voting корректно удаляет активную карту и без маркера. Совпадение имени с персонажем или посторонней моделью не приводит к её удалению или выбору вместо карты.

Проверки: Luau compile, Policy, реальные client/server factories в mock, 9 builder tests, 13 outfit tests, 12 spawn/map lifecycle сценариев, asset/protocol/XML validation и повторная сериализация. Фактический Roblox playtest исправления, executor CSG и старый клиент не проверены. Adonis/Kohl’s Admin hosted dependencies не активированы; полное ограничение — Validation_Report.md.
