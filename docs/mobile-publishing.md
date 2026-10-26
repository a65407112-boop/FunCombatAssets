# Публикация Null Protocol с телефона

Цель публикации: [Null Protocol](https://www.roblox.com/games/80093785985728/).
Place ID: `80093785985728`. Universe ID: `10767751574`.
Владелец: `TodUntitled`, user ID `11556197791`.

## Один раз добавить ключ

1. Откройте Creator Dashboard Roblox под аккаунтом владельца и перейдите в
   **API Keys → Create API Key**.
2. В **Access Permissions** добавьте **universe-places**, выберите только
   **Null Protocol**, включите операцию **Write** и создайте ключ.
   Ограничение IP, если оно включено, должно допускать GitHub runner;
   IP телефона не является адресом runner. Для одноразового обновления
   можно задать короткий срок действия ключа.
3. Откройте [секреты репозитория](https://github.com/a65407112-boop/FunCombatAssets/settings/secrets/actions),
   нажмите **New repository secret**, укажите имя `ROBLOX_API_KEY`, вставьте
   ключ в **Secret** и нажмите **Add secret**.

Ключ хранится в GitHub Secrets. Он не нужен в чате, `.rbxl`, исходниках,
файлах клиента или конфигурации ассетов.

## Обновить опубликованную игру

1. Откройте [Publish Null Protocol](https://github.com/a65407112-boop/FunCombatAssets/actions/workflows/publish-place.yml)
   в браузере телефона. При необходимости включите версию сайта для компьютера.
2. Нажмите **Run workflow**, выберите ветку **main**, затем **Run workflow**.
3. Дождитесь зелёного результата. В Summary появится номер опубликованной
   версии Roblox. При ошибке открывайте шаг **Verify release and publish the place**.
4. Зайдите в новый сервер игры и выполните обычный loader.

Кнопка публикует весь `server/funcombat_server.rbxl` поверх указанного плейса,
включая карту и серверные скрипты. Она сначала проверяет build/protocol и
SHA256 всех файлов, перечисленных в manifest, и не публикует неполный релиз.
Дополнительно проверяются типы шести восстановленных числовых свойств
`HumanoidDescription`, чтобы остановить известную ошибку формата до загрузки.
Коммиты сами по себе публикацию не запускают. Старые серверы автоматически
не перезапускаются. Сам файл `.rbxl` эта настройка не меняет.

Roblox Open Cloud ограничивает обновление `EditableImage`, `EditableMesh`,
`PartOperation` (включая `UnionOperation`), `SurfaceAppearance` и `BaseWrap`.
В текущем `.rbxl` есть 183 `UnionOperation` и 20 `SurfaceAppearance`.
Их геометрия и материалы не были изменены обновлением native R6, но после
API-публикации их отображение нужно проверить в игре. Изменения этих типов
нужно публиковать из Studio; офлайн-проверки этого ограничения не обходят.

Если запрос завершился без подтверждённого номера версии или по таймауту,
сначала проверьте историю версий в Creator Dashboard: не повторяйте запрос
вслепую. Ключ не выводится в логи, HTTP-перенаправления запрещены,
публикация не повторяется автоматически.

Официальные инструкции:
[Roblox Place Publishing](https://create.roblox.com/docs/cloud/guides/usage-place-publishing),
[Roblox API Keys](https://create.roblox.com/docs/cloud/auth/api-keys),
[GitHub Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

Офлайн-проверка команды публикации:
`python3 -m unittest discover -s tools/tests -p 'test_publish_workflow.py' -v`.
Она использует тестовый ответ API и не публикует игру.
