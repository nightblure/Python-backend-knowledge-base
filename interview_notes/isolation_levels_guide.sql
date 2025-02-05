/*
if __name__ == '__main__':
    from testcontainers.postgres import PostgresContainer
    with PostgresContainer(image="postgres:alpine3.16") as pg_container:
        pg_container.start()
        url = pg_container.get_connection_url()
        print(url)
        x = 0  # здесь можно поставить брейкпоинт, чтобы контейнер не закрылся
*/
REVOKE ALL PRIVILEGES ON SCHEMA public FROM user1;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM user2;
drop role user1;
drop role user2;
drop table if exists levels_test;
create table if not exists levels_test
(
    id    serial primary key,
    name  varchar(30),
    money integer
);
create user user1 WITH PASSWORD 'user1'
    superuser createdb createrole replication bypassrls;

create user user2 WITH PASSWORD 'user2'
    superuser createdb createrole replication bypassrls;

GRANT ALL PRIVILEGES ON SCHEMA public TO user1;
GRANT ALL PRIVILEGES ON SCHEMA public TO user2;

insert into levels_test (name, money) values ('Vanya_1', 100);
insert into levels_test (name, money) values ('Vanya_2', 100);
insert into levels_test (name, money) values ('Vanya_3', 100);

-- не забудь создать 2 отдельных коннекшена для user1 и user2!

/* READ COMMITTED: уровень по дефолту,
   защищает от аномалии "грязного чтения",
   не защищает от "неповторяемого чтения"

   Ниже запросы для создания аномалии "неповторяемое чтение":
   1. начинаем Т1 и смотрим в ней запрос - вернется 1 строка
   2. меняем money в Т2 и фиксируем
   3. запрос внутри незавершенной Т1 вернет 0 строк - чтение не повторилось
*/

-- T1
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- важно увидеть возврат нуля строк ДО коммита
select * from levels_test where name = 'Vanya_1' and money = 100;
COMMIT;

-- T2
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
update levels_test set money = 150 where name = 'Vanya_1' returning id;
COMMIT;

------------------------------------------------------------------------------

/* REPEATABLE READ: читаемые данные внутри начатой транзакции
   будут одни и те же в любом случае

   защищает от аномалии "неповторяемого чтения",
   НО не защищает от "фантомного чтения":
   например Т1 до своего коммита не увидит новые строки, созданные Т2

   Можно убедиться, что аномалии "неповторяемого чтения" теперь нет:
   1. начинаем Т1 и смотрим запрос - вернется 1 строка
   2. меняем money в Т2 и коммитим ее
   3. смотрим запрос в незавершенной Т1 - все еще имеем 1 строку
   4. коммитим Т1 и смотрим запрос - видим 0 строк, что и ожидаем
*/

-- T1
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- вернется 1 строка как и ожидаем, т.к. на этом уровне транзакция видит свой снэпшот данных
select * from levels_test where name = 'Vanya_2' and money = 100;
COMMIT;
-- а теперь ничего не увидит
select * from levels_test where name = 'Vanya_2' and money = 100;

-- T2
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
update levels_test set money = 150 where name = 'Vanya_2' returning id;
COMMIT;

------------------------------------------------------------------------------

/* SERIALIZABLE: самый строгий уровень, не допускающий
   изменений пересекающися данных в разных транзакциях

   защищает от всех аномалий:
   1. начинаем T1 и выполняем запрос
   2. начинаем Т2 и выполняем запрос - он должен залагать, т.к. данные "захвачены" Т1
   3. коммитим Т1, должны увидеть ошибку ERROR: could not serialize access due to concurrent update
*/

-- T1
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
update levels_test set money = 150 where name = 'Vanya_3' returning id;
COMMIT;

-- T2
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
update levels_test set money = 200 where name = 'Vanya_3' returning id;
COMMIT;
