redback-sync
============

Система синхронизации абонентов Carbon Billing 4 с Redback SE-100, в идеале запускаемая раз в 10 минут. Позволяет снизить вероятность лишних звонков абонентов из-за случайных потерь команд из-за проблем с сетью.

## Описание действий 

### disconnect

- у кого logged 0
- есть сессия

#### Как тестить

- авторизоваться на redback
- выполнить sqlexec "UPDATE users SET logged=0 WHERE id=\<test\_user\_id\>
- Запустить generator
- Проверить наличие var/send\_disconnect/\<test\_user\_id\>.cmd

### set_noauth

- у кого radius авторизация
- tray_agent не запущен
- не висит noauth полиси
- есть сессия

#### Как тестить

- Авторизоваться на redback
- Выключить трэйагент
- Снять появившуюся noauth policy
- Запустить generator
- Проверить наличие var/set\_noauth\_redirect/\<test\_user\_id\>.cmd

### remove_noauth

- у кого radius авторизация 
- tray_agent запущен
- при этом висит noauth полиси
- есть сессия

### set_negbal

- у кого нет денег
- при этом не висит nomoney полиси
- есть сессия

### remove_noauth

- у кого деньги есть
- но при этом висит nomoney полиси
- есть сессия

P.S: код, после перехода с static clips на non dhcp clips стал грязноватым.
