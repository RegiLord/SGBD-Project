-- 6.

-- Procedura ce ia toti utilizatori intre 2 date si pentru fiecare luam cele 5 cele mai vechi postari si facem
-- ca fiecare utilizator sa aprecieze fiecare postare

create or replace procedure LikeOldestPosts(min_date in date, max_date in date) as
    -- Problema putea fi facuta si cu cursori parametrizati, dar am folosit cele 3 tipuri de colectii

    type t_nt_users is table of UTILIZATORI.UTILIZATOR_ID%type;
    type t_v_old_posts is varray(5) of number;
    type t_it_user_posts is table of t_v_old_posts index by PLS_INTEGER;

    EXC_NO_USR exception;
    DATES_NULL exception;

    how_many_users number;
    how_many_posts number;
    is_already_liked number;
    users t_nt_users := t_nt_users();
    user_posts t_it_user_posts := t_it_user_posts();
begin
    if min_date is null and max_date is null then
        raise DATES_NULL;
    end if;

    select COUNT(UTILIZATOR_ID) into how_many_users
    from UTILIZATORI
    where DATA_CREARE_CONT between min_date and max_date;

    if how_many_users = 0 then
        raise EXC_NO_USR;
    end if;

        select UTILIZATOR_ID bulk collect into users
        from UTILIZATORI
        where DATA_CREARE_CONT between min_date and max_date;

        -- Cream un tabel indexat car foloseste utilizator la index
        -- si care la fieacre intrare are un varray cu cele 5 cele mai vechi postari
        -- daca sunt mai multe postari care pot fi considerate cele 5 cele mai vechi
        -- le luam in ordine alfabetica a numelui
        for i in 1..users.COUNT loop
            user_posts(users(i)) := t_v_old_posts();

            select POSTARE_ID bulk collect into user_posts(users(i))
            from (select * from POSTARI order by DATA_CREARE_POSTARE, POSTARE_NUME)
            where ROWNUM <= 5;
    end loop;

    for i in 1..users.COUNT loop
        for j in 1..users.COUNT loop
            for p in 1..user_posts(users(j)).COUNT loop
                select COUNT(*) into is_already_liked
                from APRECIERI
                where UTILIZATOR_ID = users(i) and POSTARE_ID = user_posts(users(j))(p);

                if is_already_liked = 0 then
                    insert into APRECIERI
                    values (users(i), user_posts(users(j))(p), SYSDATE);
                end if;
            end loop;
        end loop;
    end loop;

exception
    when DATES_NULL then
        DBMS_OUTPUT.PUT_LINE('There dates cannot be null!');
    when EXC_NO_USR then
        DBMS_OUTPUT.PUT_LINE('There are no users between dates ' || min_date || ' and ' || max_date || '!');
end;
/
delete APRECIERI;
/
begin
    LikeOldestPosts(date '2010-01-01', SYSDATE);
end;
/
begin
    LikeOldestPosts(NULL, SYSDATE);
    LikeOldestPosts(SYSDATE, SYSDATE - 100);
    LikeOldestPosts(SYSDATE - 10000, SYSDATE);
end;
/

select * from APRECIERI;
rollback;

-- 7.
-- Subprogram stocat independent care sa utilizeze 2 tipuri de cursor unul normal si unul independent, dependent
-- de celalalt cursor

-- Afisati pentru fiecare postare documentele sale (cu tipul documentulu) in ordinea descrescatoare a marimii

create or replace procedure ShowPostDocuments as
    cursor c_posts is
        select POSTARE_ID, POSTARE_NUME
        from POSTARI;

    cursor c_documente(post_id number) is
        select *
        from DOCUMENTE
        where POSTARE_ID = post_id
        order by MARIME desc;
begin
    for p in c_posts loop
        dbms_output.put(p.POSTARE_ID || ' ' || p.POSTARE_NUME || ': ');
        for d in c_documente(p.POSTARE_ID) loop
            dbms_output.put(d.DOCUMENT_NUME || '.' || d.DOCUMENT_TIP || ' ');
        end loop;
        dbms_output.put_line('');
    end loop;
end;

begin
    ShowPostDocuments();
end;

-- 8. Formulați în limbaj natural o problemă pe care să o rezolvați folosind un subprogram stocat
-- independent de tip funcție care să utilizeze într-o singură comandă SQL 3 dintre tabelele create.
-- Tratați toate excepțiile care pot apărea, incluzând excepțiile predefinite NO_DATA_FOUND și
-- TOO_MANY_ROWS. Apelați subprogramul astfel încât să evidențiați toate cazurile tratate

-- Returnati post_id-ul celei mai apreciate postari dintr-o comunitate
-- (community_name este parametru, pot fi si null)
-- daca nu este nicio postare apreciata returnam null
-- daca community_name e null inseamna ca e din orice comunitate
-- daca sunt mai multe postari cu acelasi numar de aprecieri luam postare cea mai noua

create or replace function Most_Liked_Post_In_Community(
                        community COMUNITATI.COMUNITATE_NUME%type
                    )
return POSTARI.POSTARE_ID%type
is
    NO_COM exception;
    most_liked number;
    com number;
begin
    select COUNT(COMUNITATE_ID) into com
    from COMUNITATI
    where community is null or COMUNITATE_NUME = community;

    if com = 0 then
        raise NO_COM;
    end if;

    select P.POSTARE_ID into most_liked
    from (
        select P1.POSTARE_ID, COUNT(A.POSTARE_ID) "LIKES"
        from POSTARI P1
        join APRECIERI A on A.POSTARE_ID = P1.POSTARE_ID
        left join COMUNITATI C on C.COMUNITATE_ID = P1.COMUNITATE_ID
        where community is null or C.COMUNITATE_NUME = community
        group by P1.POSTARE_ID, P1.COMUNITATE_ID, P1.CREATOR_ID, P1.DATA_CREARE_POSTARE
        order by LIKES desc, P1.DATA_CREARE_POSTARE desc
         ) P
    where ROWNUM <= 1;

    return most_liked;
exception
    when NO_DATA_FOUND then
        DBMS_OUTPUT.PUT_LINE('WARNING: No post with more than one like!');
        return null;
    when TOO_MANY_ROWS then
        -- Nu cred ca este posibil sa avem too many rows deoarece ROWNUM <= 1 dar am pus oricum exceptia
        return null;
    when NO_COM then
        DBMS_OUTPUT.PUT_LINE('WARNING: No community with name ' || community || '  !');
        return null;
end;

declare
    n number;
begin
    -- Primul Test e pntru o comunitate care nu există ne așteptăm la null ca răspuns
    n := Most_Liked_Post_In_Community('nu exista');
    if n is null then
        DBMS_OUTPUT.PUT_LINE('CORRECT ANSWER!');
    end if;

    -- Al doilea Teste este pentru când nu avem postări apreciate, ar trebui intra la cazul
    -- NO_DATA_FOUND, așteptăm valoare de retur null
    delete APRECIERI;
    n := Most_Liked_Post_In_Community('AIClub');
    if n is null then
        DBMS_OUTPUT.PUT_LINE('CORRECT ANSWER!');
    end if;
    rollback;

    -- Al Treilea teste este unul valid, avem să dăm null parametrului de comunitate care va însemna că
    -- căutam cea mai apreciată postare
    -- Ca răspuns ar trebui să fie postarea 1002
    n := Most_Liked_Post_In_Community(NULL);
    if n is not null then
        DBMS_OUTPUT.PUT_LINE(n);
        DBMS_OUTPUT.PUT_LINE('CORRECT ANSWER!');
    end if;
end;

select  P.POSTARE_ID, P.DATA_CREARE_POSTARE, COUNT(UTILIZATOR_ID) "LIKES"
from POSTARI P
join APRECIERI A on A.POSTARE_ID = P.POSTARE_ID
group by P.POSTARE_ID, P.DATA_CREARE_POSTARE;


-- 9. Formulați în limbaj natural o problemă pe care să o rezolvați folosind un subprogram stocat
-- independent de tip procedură care să aibă minim 2 parametri și să utilizeze într-o singură
-- comandă SQL 5 dintre tabelele create. Definiți minim 2 excepții proprii, altele decât cele
-- predefinite la nivel de sistem. Apelați subprogramul astfel încât să evidențiați toate cazurile definite
-- și tratate.

-- Parametri (min_date, max_date, nume_comunitate)

-- Returnati numele categorieri cele mai folosite utilizatori care au intrat intre <min_date> si <max_date> in
-- comunitatea <nume_comunitate>

-- REGULI:
-- min_join_date si max_join_date nu pot fi nule
-- daca community e NULL consideram orice comunitate
-- categ poate fi o singura categorie, daca avem mai multe returnam null


-- Tabele folosite (USER_COMUNITATE, COMUNITATI, POSTARI, CATEGORII_POSTARI, CATEGORII)

create or replace procedure Most_Used_Category_In_Com
                            (
                                min_join_date in date,
                                max_join_date in date,
                                community in COMUNITATI.COMUNITATE_NUME%type,
                                categ out CATEGORII.CATEGORIE_NUME%type
                            )
is
    type r_cat_ap is record (
            categorie_nume CATEGORII.CATEGORIE_NUME%type,
            appears number
    );

    type ti_cat_ap is table of r_cat_ap;

    cat_ap ti_cat_ap;

    DATES_NULL exception;
    NO_COM exception;
    NO_PEOPLE_JOINED exception;
    NO_CATEGORIES exception;
    TOO_MANY_CATEGORIES exception;

    nr number;
    com_exists number;
    people_joined number;
begin
    categ := NULL;

    if min_join_date is null or max_join_date is null then
        raise DATES_NULL;
    end if;

    select COUNT(COMUNITATE_ID) into com_exists
    from COMUNITATI
    where community is null or UPPER(COMUNITATE_NUME) = UPPER(community);

    if com_exists = 0 then
        raise NO_COM;
    end if;

    -- join normal, in USER_COMUNITATE (MEMBRU_ID, COMUNITATE_ID) e primary key
    select COUNT(*) into people_joined
    from USER_COMUNITATE UC
    join COMUNITATI C on C.COMUNITATE_ID = UC.COMUNITATE_ID
    where UC.DATA_INTRARE between min_join_date and max_join_date
        and (community is null or UPPER(C.COMUNITATE_NUME) = UPPER(community));

    if people_joined = 0 then
        raise NO_PEOPLE_JOINED;
    end if;
    -- in CATEGORII_POSTARI (CATEGORIE_ID, POSTARE_ID) e primary key
    -- de clarificat daca o postare apare de 0 ori nu este pusa in cat_ap
    select CT.CATEGORIE_NUME, COUNT(CP.CATEGORIE_ID) "APPEARS" bulk collect into cat_ap
    from CATEGORII CT
    join CATEGORII_POSTARI CP on CP.CATEGORIE_ID = CT.CATEGORIE_ID
    join POSTARI P on P.POSTARE_ID = CP.POSTARE_ID
    left join COMUNITATI CM on CM.COMUNITATE_ID = P.COMUNITATE_ID
    where P.CREATOR_ID in (select MEMBRU_ID
                            from USER_COMUNITATE UC
                            join COMUNITATI C on C.COMUNITATE_ID = UC.COMUNITATE_ID
                            where UC.DATA_INTRARE between min_join_date and max_join_date
                                and (community is null or UPPER(C.COMUNITATE_NUME) = UPPER(community)))
        and (community is null or UPPER(CM.COMUNITATE_NUME) = UPPER(community))
    group by CT.CATEGORIE_NUME
    order by APPEARS desc;

    if cat_ap.COUNT = 0 then
        raise NO_CATEGORIES;
    end if;

    nr := 0;

    for i in 1..cat_ap.COUNT loop
        if cat_ap(i).appears = cat_ap(1).appears then
            nr := nr + 1;
        end if;
    end loop;

    if nr > 1 then
        raise TOO_MANY_CATEGORIES;
    end if;

    categ := cat_ap(1).categorie_nume;

exception
    when DATES_NULL then
        raise_application_error(-20345, 'ERROR: Procedure cannot be called with null dates!');
    when NO_COM then
        DBMS_OUTPUT.PUT_LINE('WARNING: No community exists with name ' || community || ' !');
    when NO_PEOPLE_JOINED then
        DBMS_OUTPUT.PUT_LINE('WARNING: No people joined the given community between '
                                || min_join_date || ' and '
                                || max_join_date || '!');
    when NO_CATEGORIES then
        DBMS_OUTPUT.PUT_LINE('WARNING: No categories used by posts from relevant users!');
    when TOO_MANY_CATEGORIES then
        DBMS_OUTPUT.PUT_LINE('WARNING: More than one category fits the rule!');
end;

-- DATE_NULL EXCEPTION
declare
    categ varchar2(100);
begin
    MOST_USED_CATEGORY_IN_COM(NULL, SYSDATE, 'Aiclub', categ);
end;

declare
    categ varchar2(100);
begin
    -- NO_COM EXCEPTION
    MOST_USED_CATEGORY_IN_COM(SYSDATE, SYSDATE, 'asd', categ);
    -- VERIFICARE CA RETURNEAZA CORECT
    if categ is not null then
        DBMS_OUTPUT.PUT_LINE('WRONG ANSWER!');
    end if;

    -- NO_PEOPLE_JOINED EXCEPTION
    MOST_USED_CATEGORY_IN_COM(SYSDATE, SYSDATE - 1, NULL, categ);
    if categ is not null then
        DBMS_OUTPUT.PUT_LINE('WRONG ANSWER!');
    end if;

    -- o sa cream artificial testul
    delete from CATEGORII_POSTARI;
    -- NO_CATEGORIES
    MOST_USED_CATEGORY_IN_COM(date '2000-01-01', SYSDATE, NULL, categ);
    if categ is not null then
        DBMS_OUTPUT.PUT_LINE('WRONG ANSWER!');
    end if;
    rollback;

    -- TOO_MANY_CATEGORIES
    MOST_USED_CATEGORY_IN_COM(date '2000-01-01', SYSDATE, NULL, categ);
    if categ is not null then
        DBMS_OUTPUT.PUT_LINE('WRONG ANSWER!');
    end if;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('A valid querry:');

    delete from CATEGORII_POSTARI
    where POSTARE_ID = 1003 and CATEGORIE_ID != 1;
    -- raspunsul ar trebui sa fie categoria cu id-ul 1 -> General
    MOST_USED_CATEGORY_IN_COM(date '2000-01-01', SYSDATE, 'AICLUB', categ);
    if categ is null then
        DBMS_OUTPUT.PUT_LINE('WRONG ANSWER!');
    end if;

    DBMS_OUTPUT.PUT_LINE('ANSWER: ' || categ);
    rollback;
end;

select * from POSTARI;


--12. Definiți un trigger de tip LDD. Declanșați trigger-ul.

-- Trigger LDD: se declanșează la ALTER TABLE
create or replace trigger TRG_ALTER_TABLE_USER
after alter on schema   -- poate fi "database" pentru toate tabelele
declare
    user varchar2(30);
    object varchar2(30);
begin
    user := sys_context('USERENV', 'SESSION_USER');
    object := ora_dict_obj_name;

    dbms_output.put_line('User "' || user || '" has altered table: ' || object);
end;
/
alter table UTILIZATORI add (telefon varchar2(30));
alter table UTILIZATORI drop column telefon;

-- 13

create or replace package TITLE_MANAGEMENT as

    type t_titles is table of TITLURI%rowtype;
    type r_owner is record (
                        user_id UTILIZATORI.UTILIZATOR_ID%type,
                        user_name UTILIZATORI.USERNAME%type
                    );
    type t_owners is table of r_owner;

    cursor c_titles_com(com_id COMUNITATI.COMUNITATE_ID%type) is
        select * from TITLURI where COMUNITATE_ID = com_id;

    NO_COMMUNITY exception;
    NO_TITLE exception;
    NO_USER exception;
    last_sp_status boolean := TRUE;

    procedure DELETE_TITLE (
            title_id IN TITLURI.TITLU_ID%type
        );
    procedure DELETE_OWNERSHIP (
            title_id IN TITLURI.TITLU_ID%type,
            user_name IN UTILIZATORI.USERNAME%type
        );

    procedure ADD_TITLE (
            title_name IN TITLURI.TITLU_NUME%type,
            com_name IN COMUNITATI.COMUNITATE_NUME%type,
            color IN TITLURI.CULOARE%type
        );

    --< username-ul este unic >--
    procedure GIVE_TITLE (
        title_id IN TITLURI.TITLU_ID%type,
        user_name IN UTILIZATORI.USERNAME%type
    );

    --< La cazuri cu nume este case sensitive >--
    function COMMUNITY_EXISTS(com_name COMUNITATI.COMUNITATE_NUME%type) return boolean;
    function USER_EXISTS(user_name UTILIZATORI.USERNAME%type) return boolean;
    function TITLE_EXISTS(title_id TITLURI.TITLU_ID%type) return boolean;
    function TITLE_EXISTS(title_name TITLURI.TITLU_NUME%type) return boolean;
    function OWNS_TITLE(
        user_name UTILIZATORI.USERNAME%type,
        title_id TITLURI.TITLU_ID%type
    ) return boolean;

    function NR_OWNERS_TITLE (
        title_id TITLURI.TITLU_ID%type
    ) return number;

    procedure GET_OWNERS(
        title_id IN TITLURI.TITLU_ID%type,
        owners OUT t_owners
    );
    function GET_OWNERS (title_id TITLURI.TITLU_ID%type) return t_owners;

    procedure GET_TITLE(
        title_id IN TITLURI.TITLU_ID%type,
        title_row OUT TITLURI%rowtype
    );
    function GET_TITLE(title_id TITLURI.TITLU_ID%type) return TITLURI%rowtype;

    procedure GET_TITLES(titles OUT t_titles);
    function GET_TITLES return t_titles;

    procedure GET_TITLES_FROM_COMMUNITY(
        com_name IN COMUNITATI.COMUNITATE_NUME%type,
        titles OUT t_titles
    );
    function GET_TITLES_FROM_COMMUNITY(com_name COMUNITATI.COMUNITATE_NUME%type) return t_titles;
end TITLE_MANAGEMENT;

create or replace package body TITLE_MANAGEMENT as
    function TITLE_EXISTS(title_id TITLURI.TITLU_ID%type) return boolean is
        n number;
    begin
        last_sp_status := FALSE;
        select COUNT(TITLU_ID) into n
        from TITLURI
        where TITLU_ID = title_id;

        last_sp_status := TRUE;
        if n = 0 then
            return FALSE;
        end if;
        return TRUE;
    end;

    function TITLE_EXISTS(title_name TITLURI.TITLU_NUME%type) return boolean is
        n number;
    begin
        last_sp_status := FALSE;
        select COUNT(TITLU_ID) into n
        from TITLURI
        where TITLU_NUME = title_name;

        last_sp_status := TRUE;
        if n = 0 then
            return FALSE;
        end if;
        if n > 1 then
            DBMS_OUTPUT.PUT_LINE('WARNING: More than one title with name ' || title_name);
        end if;
        return TRUE;
    end;

    function COMMUNITY_EXISTS(com_name COMUNITATI.COMUNITATE_NUME%type) return boolean is
        n number;
    begin
        last_sp_status := FALSE;
        select COUNT(COMUNITATE_ID) into n
        from COMUNITATI
        where COMUNITATE_NUME = com_name;

        last_sp_status := TRUE;
        if n = 0 then
            return FALSE;
        end if;
        return TRUE;
    end;

    function USER_EXISTS(user_name UTILIZATORI.USERNAME%type) return boolean is
        n number;
    begin
        last_sp_status := FALSE;
        select COUNT(UTILIZATOR_ID) into n
        from UTILIZATORI
        where USERNAME = user_name;

        last_sp_status := TRUE;
        if n = 0 then
            return FALSE;
        end if;
        return TRUE;
    end;

    function OWNS_TITLE(
        user_name UTILIZATORI.USERNAME%type,
        title_id TITLURI.TITLU_ID%type
    ) return boolean is
        n number;
    begin
        last_sp_status := FALSE;
        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        if not USER_EXISTS(user_name) then
            raise NO_USER;
        end if;

        select COUNT(*) into n
        from TITLURI_USER TU
        join UTILIZATORI U on U.UTILIZATOR_ID = TU.UTILIZATOR_ID
        where TITLU_ID = title_id and U.USERNAME = user_name;

        last_sp_status := TRUE;
        if n = 0 then
            return FALSE;
        end if;
        return TRUE;
    end;


    function NR_OWNERS_TITLE (
        title_id TITLURI.TITLU_ID%type
    ) return number is
        n number;
    begin
        last_sp_status := FALSE;
        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select COUNT(*) into n
        from TITLURI_USER
        where TITLU_ID = title_id;

        last_sp_status := TRUE;
        return n;
    end;

    procedure GET_TITLE(
        title_id IN TITLURI.TITLU_ID%type,
        title_row OUT TITLURI%rowtype
    ) is
    begin
        last_sp_status := FALSE;
        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select * into title_row
        from TITLURI
        where TITLU_ID = title_id;
        last_sp_status := TRUE;
    end;
    function GET_TITLE(title_id TITLURI.TITLU_ID%type) return TITLURI%rowtype is
        title_row TITLURI%rowtype;
    begin
        last_sp_status := FALSE;
        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select * into title_row
        from TITLURI
        where TITLU_ID = title_id;
        last_sp_status := TRUE;
        return title_row;
    end;

    procedure GET_TITLES(titles OUT t_titles) is
    begin
        last_sp_status := FALSE;
        select * bulk collect into titles
        from TITLURI;
        last_sp_status := TRUE;
    end;
    function GET_TITLES return t_titles is
        titles t_titles;
    begin
        last_sp_status := FALSE;
        select * bulk collect into titles
        from TITLURI;
        last_sp_status := TRUE;
        return titles;
    end;

    procedure GET_TITLES_FROM_COMMUNITY(
        com_name IN COMUNITATI.COMUNITATE_NUME%type,
        titles OUT t_titles
    ) is
        com_id number;
    begin
        last_sp_status := FALSE;
        if not COMMUNITY_EXISTS(com_name) then
            raise NO_COMMUNITY;
        end if;

        select COMUNITATE_ID into com_id
        from COMUNITATI
        where COMUNITATE_NUME = com_name;

        titles := t_titles();
        for title in c_titles_com(com_id) loop
            titles.EXTEND;
            titles(titles.LAST) := title;
        end loop;

        last_sp_status := TRUE;
    exception
        when NO_DATA_FOUND then
            raise_application_error(-20345, 'ERROR: COMMUNITY_EXISTS check failed, community does not exit! ('
                                                || com_name || ')');
        when TOO_MANY_ROWS then
            raise_application_error(-20345, 'ERROR: COMMUNITY_NAME UNIQUE check failed, more than one community exist! ('
                                                || com_name || ')');
    end;

    function GET_TITLES_FROM_COMMUNITY(com_name COMUNITATI.COMUNITATE_NUME%type) return t_titles is
        titles t_titles := t_titles();
        com_id number;
    begin
        last_sp_status := FALSE;
        if not COMMUNITY_EXISTS(com_name) then
            raise NO_COMMUNITY;
        end if;

        select COMUNITATE_ID into com_id
        from COMUNITATI
        where COMUNITATE_NUME = com_name;

        for title in c_titles_com(com_id) loop
            titles.EXTEND;
            titles(titles.LAST) := title;
        end loop;

        last_sp_status := TRUE;
        return titles;
    exception
        when NO_DATA_FOUND then
            raise_application_error(-20345, 'ERROR: COMMUNITY_EXISTS check failed, community does not exit! ('
                                                || com_name || ')');
        when TOO_MANY_ROWS then
            raise_application_error(-20345, 'ERROR: COMMUNITY_NAME UNIQUE check failed, more than one community with the same name! ('
                                                || com_name || ')');
    end;

     procedure ADD_TITLE (
            title_name IN TITLURI.TITLU_NUME%type,
            com_name IN COMUNITATI.COMUNITATE_NUME%type,
            color IN TITLURI.CULOARE%type
        ) is
         com_id number;
    begin
        last_sp_status := FALSE;
        if not COMMUNITY_EXISTS(com_name) then
            raise NO_COMMUNITY;
        end if;

        select COMUNITATE_ID into com_id
        from COMUNITATI
        where COMUNITATE_NUME = com_name;

        insert into TITLURI
        values (SEQ_TITLURI.nextval, com_id, title_name, color);
        last_sp_status := TRUE;
    exception
      when NO_DATA_FOUND then
            raise_application_error(-20345, 'ERROR: COMMUNITY_EXISTS check failed, community does not exit! ('
                                                || com_name || ')');
        when TOO_MANY_ROWS then
            raise_application_error(-20345, 'ERROR: COMMUNITY_NAME UNIQUE check failed, more than one community with the same name! ('
                                                || com_name || ')');
    end;

    --< username-ul este unic >--
    procedure GIVE_TITLE(
        title_id IN TITLURI.TITLU_ID%type,
        user_name IN UTILIZATORI.USERNAME%type
    ) is
        user_id number;
    begin
        last_sp_status := FALSE;
        if not USER_EXISTS(user_name) then
            raise NO_USER;
        end if;

        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select UTILIZATOR_ID into user_id
        from UTILIZATORI
        where USERNAME = user_name;

        insert into TITLURI_USER
        values (title_id, user_id);
        last_sp_status := TRUE;
    exception
     when DUP_VAL_ON_INDEX then
        last_sp_status := TRUE;
        DBMS_OUTPUT.PUT_LINE('WARNING: TITLURI_USER entry already exists');
     when NO_DATA_FOUND then
        raise_application_error(-20345, 'ERROR: USER_EXISTS check failed, user does not exit! ('
                                                || user_name || ')');
    when TOO_MANY_ROWS then
        raise_application_error(-20345, 'ERROR: USER_NAME UNIQUE check failed, more than one user with the same name! ('
                                                || user_name || ')');
    end;

    procedure GET_OWNERS(
        title_id IN TITLURI.TITLU_ID%type,
        owners OUT t_owners
    ) is
    begin
        last_sp_status := FALSE;

        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select TU.UTILIZATOR_ID, U.USERNAME bulk collect into owners
        from TITLURI_USER TU
        join UTILIZATORI U on U.UTILIZATOR_ID = TU.UTILIZATOR_ID
        where TU.TITLU_ID = title_id;
        last_sp_status := TRUE;
    end;

    function GET_OWNERS (title_id TITLURI.TITLU_ID%type) return t_owners is
        owners t_owners := t_owners();
    begin
        last_sp_status := FALSE;

        if not TITLE_EXISTS(title_id) then
            raise NO_TITLE;
        end if;

        select TU.UTILIZATOR_ID, U.USERNAME bulk collect into owners
        from TITLURI_USER TU
        join UTILIZATORI U on U.UTILIZATOR_ID = TU.UTILIZATOR_ID
        where TU.TITLU_ID = title_id;
        last_sp_status := TRUE;
        return owners;
    end;

    procedure DELETE_TITLE (
            title_id IN TITLURI.TITLU_ID%type
        ) is
    begin
        last_sp_status := FALSE;

        if not TITLE_EXISTS(title_id) then
            last_sp_status := TRUE;
            DBMS_OUTPUT.PUT_LINE('WARNING: title with id ' || title_id || ' does not exist!');
        end if;

        delete from TITLURI
        where TITLU_ID = title_id;
        last_sp_status := TRUE;
    end;

    procedure DELETE_OWNERSHIP (
            title_id IN TITLURI.TITLU_ID%type,
            user_name IN UTILIZATORI.USERNAME%type
        ) is
        user_id number;
    begin
        last_sp_status := FALSE;

        if OWNS_TITLE(user_name, title_id) then
            select UTILIZATOR_ID into user_id
            from UTILIZATORI
            where USERNAME = user_name;

            delete from TITLURI_USER
            where UTILIZATOR_ID = user_id and TITLU_ID = title_id;

        end if;
    end;
end TITLE_MANAGEMENT;


declare
    titluri TITLE_MANAGEMENT.t_titles;
    owners TITLE_MANAGEMENT.t_owners;
    com_name varchar2(100);
begin
    select COMUNITATE_NUME into com_name
    from COMUNITATI
    where COMUNITATE_ID = 10;

    titluri := TITLE_MANAGEMENT.GET_TITLES_FROM_COMMUNITY(com_name);

    for i in 1..titluri.COUNT loop
        owners := TITLE_MANAGEMENT.GET_OWNERS(titluri(i).TITLU_ID);

        DBMS_OUTPUT.PUT(titluri(i).TITLU_NUME || ': ');

        for j in 1..owners.COUNT loop
            DBMS_OUTPUT.PUT(owners(j).USER_NAME || ' ');
        end loop;
        DBMS_OUTPUT.PUT_LINE('');
    end loop;
exception
    when NO_DATA_FOUND then
        DBMS_OUTPUT.PUT_LINE('No community with id 10!');
end;

select * from TITLURI_USER


-- vreau o functie / procedura care returneaza un table of
-- record ( title_name, community_name, color, table of (user_names) )
