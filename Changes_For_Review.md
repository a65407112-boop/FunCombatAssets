# Изменения сборки

Добавлен воспроизводимый Builder из конкретного приложенного плейса. Результаты: funcombat_server.rbxl, Game_Server.rbxlx, Game_GitHub.zip, Game_ExecutorSide.zip и loader.lua. Исходный файл сохранён.

Полная серверная адаптация исходных механик находится в Builder/templates/server: бой, авторитетные попадания/урон, восстановление, перенос и исполнения, все исходные парные варианты, шкала/Completions, окружение, голосование, погода и R6 avatar normalization. Перенесены LowerRig/TorsoRig и все 47 последовательностей. Исходные данные и программы сохранены в source.

Клиент обновлён под encoded protocol 4 с точным build ID. Восстановление typed Instances/refs дополнено настоящим CSG deserialization. Добавлены bootstrap buffer, dependency traversal, manifest integrity, snapshots, respawn и cleanup повторного запуска.

Проверки: Luau compile, Policy, реальные client/server factories в mock, 6 builder tests, 13 outfit tests, asset/protocol/XML validation и повторная сериализация. Фактический Roblox playtest, executor CSG и старый клиент не проверены. Adonis/Kohl’s Admin hosted dependencies не активированы; полное ограничение — Validation_Report.md.
