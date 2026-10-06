# Что перенесено

Источник — приложенный бинарный плейс; старый README не определяет состав. Исходные две карты, Terrain, спавны, окружение, оружие, GUI, 47 stored animation sequences, LowerRig/TorsoRig, звуки и эффекты экспортированы из его реальных объектов.

Сервер: combo, startup/active hit windows, урон, stun/counter, downing/recovery, ragdoll, carry/drop, обе финальные атаки, awakening, regen, emotes, Gender/Info, исходная встроенная админ-панель, voting/weather, TV, teleport, killboxes, rotation, music, dummy commands и secret door. Парные варианты Default/FD/Wall используют исходные модели/анимации, stop/hold/wall prompts, Meter, R/mobile R и Completions.

Клиент: original resource reconstruction, protocol/build matching, server-time playback, late joining, respawn and repeated-loader cleanup. Карта и авторитетные тела остаются на сервере. Клиентские эффекты явно рассылаются сервером; локальный эффект не считается автоматической репликацией.

Изменения ненадёжных исходных мест: клиент больше не задаёт урон, цели и произвольный этап; сервер проверяет hold/distance/ownership. Пороги этапов закреплены как 0.28/0.62/1 по исходным проверкам предыдущего значения шкалы. Создание dummy ограничено: cooldown 3 секунды, 4 на игрока, 20 на сервер. Повторная загрузка и завершение взаимодействий имеют cleanup. Kohl’s Admin подключён через оригинальный require(1868400649), native Settings/Custom Commands и bridge к исходному dummy spawner. Adonis сохранён для просмотра и не активирован. Hosted код этих систем не содержится в оригинальном плейсе или архиве.

Это сборка с офлайн-проверками. Функциональное и визуальное равенство игры в Roblox не подтверждено; геометрия по запросу владельца не инспектировалась. Полные результаты и ограничения: ../Validation_Report.md.
