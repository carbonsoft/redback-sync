redback-sync
============

Система синхронизации абонентов Carbon Billing 4 с Redback SE-100, в идеале запускаемая раз в 10 минут. Позволяет снизить вероятность лишних звонков абонентов из-за случайных потерь команд из-за проблем с сетью.

- disconnect всем, у кого logged 0 и есть сессия
- set\_noauth всем у кого radius авторизация и tray_agent не запущен и при этом не висит noauth полиси и есть сессия
- remove\_noauth всем у кого radius авторизация и tray_agent запущен и при этом висит noauth полиси и есть сессия
- set\_negbal всем у кого нет денег, но при этом не висит nomoney полиси и есть сессия
- remove\_noauth всем у кого деньги есть, но при этом висит nomoney полиси  и есть сессия

P.S: код, после перехода с static clips на non dhcp clips стал грязноватым.
