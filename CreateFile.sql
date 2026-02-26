CREATE TABLE UTILIZATORI (
    UTILIZATOR_ID       NUMBER(7) PRIMARY KEY,
    USERNAME            VARCHAR2(20) UNIQUE NOT NULL,
    GMAIL               VARCHAR2(100) NOT NULL,
    PAROLA              VARCHAR2(50) NOT NULL,
    ACTIV               VARCHAR2(5) DEFAULT 'TRUE' NOT NULL,
    DATA_CREARE_CONT    DATE DEFAULT SYSDATE NOT NULL,
    DATA_DE_NASTERE     DATE,
    --
    CONSTRAINT ACTIV_TRUE_FALSE
            CHECK (ACTIV IN ('TRUE', 'FALSE')),
    CONSTRAINT DATA_NASTERE_VALIDA
        CHECK (DATA_DE_NASTERE IS NULL OR
                DATA_DE_NASTERE < DATA_CREARE_CONT),
    CONSTRAINT MINIMUM_5_ANI
        CHECK(DATA_DE_NASTERE IS NULL OR
                DATA_CREARE_CONT - DATA_DE_NASTERE > 1825)
    -- Pe Trigger
    -- Daca adaugam o valoare in Active ii dam upper case
    -- Trigger ca data_creare_cont nu poate fi updatat
);

CREATE TABLE URMARITORI (
    URMARITOR_ID    NUMBER(7),
    URMARIT_ID      NUMBER(7),
    --
    PRIMARY KEY (URMARITOR_ID, URMARIT_ID),
    FOREIGN KEY (URMARITOR_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE CASCADE,
    FOREIGN KEY (URMARIT_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE CASCADE,
    --
    CONSTRAINT SELF_FOLLOW_CONSTRAINT
        CHECK (URMARIT_ID <> URMARITOR_ID)
    --
);

CREATE TABLE COMUNITATI (
    COMUNITATE_ID           NUMBER(7) PRIMARY KEY,
    CREATOR_ID              NUMBER(7),
    COMUNITATE_NUME         VARCHAR2(100) UNIQUE NOT NULL,
    DATA_CREARE_COMUNITATE  DATE DEFAULT SYSDATE NOT NULL,
    --
    FOREIGN KEY (CREATOR_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE SET NULL
    -- On trigget
    -- Nu poate fii data crearii comunitati mai devreme decat data crearii contului creatorului
    -- De asemenea cand este creata o comunitate vrem sa dam insert in user_comunitate
    -- La perechea de comunitate creata si user-ul creat cu rol 'ADMIN' si data_intrare data_creare
    -- Trigget data_creare_comunitate nu poate fi updatat
);

CREATE TABLE USER_COMUNITATE (
    MEMBRU_ID           NUMBER(7),
    COMUNITATE_ID       NUMBER(7),
    ROL VARCHAR2(10)    DEFAULT 'USER' NOT NULL,
    DATA_INTRARE        DATE DEFAULT SYSDATE NOT NULL,
    --
    PRIMARY KEY (MEMBRU_ID, COMUNITATE_ID),
    FOREIGN KEY (MEMBRU_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE CASCADE,
    FOREIGN KEY (COMUNITATE_ID) REFERENCES COMUNITATI (COMUNITATE_ID) ON DELETE CASCADE,
    CONSTRAINT USER_COMUNITATE_ROL
        CHECK (ROL IN ('USER', 'ADMIN', 'MODERATOR'))
    --
    /*
     On trigger la insert si update
     Nu poate data_intrarii sa fie mai mica ca data_crearii_comunitati nici ca data_creari contului membrului
     -- Data_Intrare nu poate fi updatat
     */
);

CREATE TABLE TITLURI (
    TITLU_ID        NUMBER(7) PRIMARY KEY,
    COMUNITATE_ID   NUMBER(7) NOT NULL,
    TITLU_NUME      VARCHAR2(50) NOT NULL,
    CULOARE         VARCHAR2(20) DEFAULT 'ALB',
    --
    FOREIGN KEY (COMUNITATE_ID) REFERENCES COMUNITATI (COMUNITATE_ID) ON DELETE CASCADE,
    CONSTRAINT CULOARE_VALABILA
        CHECK ( CULOARE is NULL or
            CULOARE IN ('ROSU', 'VERDE', 'GALBEN',
        'ALBASTRU', 'MOV', 'PORTOCALIU', 'ROZ', 'NEGRU', 'ALB')),
    CONSTRAINT TITLU_CULOARE_COMUNITATE_UNIC
        UNIQUE (COMUNITATE_ID, TITLU_NUME, CULOARE)
    --
    /*
     La fel ca la activ on trigger dam uppercase la culoare
     */
);

CREATE TABLE TITLURI_USER (
    TITLU_ID        NUMBER(7),
    UTILIZATOR_ID   NUMBER(7),
    --
    PRIMARY KEY (TITLU_ID, UTILIZATOR_ID), 
    FOREIGN KEY (TITLU_ID) REFERENCES TITLURI (TITLU_ID) ON DELETE CASCADE,
    FOREIGN KEY (UTILIZATOR_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE CASCADE
    --
);

CREATE TABLE CATEGORII (
    CATEGORIE_ID        NUMBER(7) PRIMARY KEY,
    CATEGORIE_NUME      VARCHAR2(100) NOT NULL,
    PG_RATING           VARCHAR2(5) DEFAULT 'PG-13',
    --
    CONSTRAINT CONSTRANGERE_PG_RATING
        CHECK(PG_RATING IS NULL OR 
              UPPER(PG_RATING) IN ('G', 'PG', 'PG-13', 'R', 'NC-17'))
    --
    /*
        Cam la fel ca la activ etc facem uppercase on trigger
    */
);

CREATE TABLE POSTARI (
    POSTARE_ID              NUMBER(7) PRIMARY KEY,
    CREATOR_ID              NUMBER(7),
    COMUNITATE_ID           NUMBER(7),
    POSTARE_MAMA_ID         NUMBER(7),
    DATA_CREARE_POSTARE     DATE DEFAULT SYSDATE NOT NULL,
    POSTARE_NUME            VARCHAR2(20) NOT NULL,
    --
    FOREIGN KEY (CREATOR_ID) REFERENCES UTILIZATORI (UTILIZATOR_ID) ON DELETE SET NULL,
    FOREIGN KEY (COMUNITATE_ID) REFERENCES COMUNITATI (COMUNITATE_ID) ON DELETE SET NULL,
    FOREIGN KEY (POSTARE_MAMA_ID) REFERENCES POSTARI (POSTARE_ID) ON DELETE CASCADE
    --
    /*
    Mai multe triggere in principiu legate de data
    Data_Crearii_Postarii > Data_creare_comunitate
    Data_Crearii_Postarii > Data_creare_creator_id
    Data_Crearii_Postarii > Data_creare_postare_mama
    Data_crearii-postarii nu poate fi modificata
    */
);

CREATE TABLE DOCUMENTE (
    DOCUMENT_ID         NUMBER(7) PRIMARY KEY,
    POSTARE_ID          NUMBER(7) NOT NULL,
    DOCUMENT_NUME       VARCHAR2(50) NOT NULL,
    DOCUMENT_TIP        VARCHAR2(4) DEFAULT 'TXT',
    MARIME              NUMBER(7), -- Bytes
    --
    FOREIGN KEY (POSTARE_ID) REFERENCES POSTARI (POSTARE_ID) ON DELETE CASCADE,
    --
    CONSTRAINT MARIME_POZITIVA 
        CHECK (MARIME IS NULL OR MARIME > 0),
    CONSTRAINT DOCUMENT_TIP_VALABIL
        CHECK (DOCUMENT_TIP IS NULL OR
            DOCUMENT_TIP IN ('TXT', 'PDF',
            'PNG', 'JPEG', 'DOC', 'DOCS', 'JPG', 'MP3')),
    CONSTRAINT DOCUMENT_NUME_UNIC
        UNIQUE (DOCUMENT_NUME, DOCUMENT_TIP)
    --
    /*
        Upper case pe document_tip
    */
);

CREATE TABLE CATEGORII_POSTARI (
    POSTARE_ID      NUMBER(7),
    CATEGORIE_ID    NUMBER(7),
    --
    PRIMARY KEY (POSTARE_ID, CATEGORIE_ID),
    FOREIGN KEY (POSTARE_ID) REFERENCES POSTARI (POSTARE_ID) ON DELETE CASCADE,
    FOREIGN KEY (CATEGORIE_ID) REFERENCES CATEGORII (CATEGORIE_ID) ON DELETE CASCADE
    --
    /*
        Daca vreau pot face o conditie ca postarea nu poate avea tag-uri de pg rating respectiv
        in functie de data_nasterii_creatorului postarii (daca aceasta e nula ignoram)
        cu trigger
    */
);

CREATE TABLE APRECIERI (
    UTILIZATOR_ID       NUMBER(7),
    POSTARE_ID          NUMBER(7),
    DATA_APRECIERE      DATE DEFAULT SYSDATE NOT NULL,
    --
    PRIMARY KEY (UTILIZATOR_ID, POSTARE_ID),
    FOREIGN KEY (UTILIZATOR_ID) REFERENCES  UTILIZATORI (UTILIZATOR_ID) ON DELETE CASCADE,
    FOREIGN KEY (POSTARE_ID) REFERENCES POSTARI (POSTARE_ID) ON DELETE CASCADE
    --
    /* cu triggere
        DATA_APRECIERE nu poate fi schimbata
       Data_Apreciere > Data_creare_utilizator
       Data_apreciere > Datat_creare_postare
    */
);

--[[ ID SEQUENCES ]]--
CREATE SEQUENCE seq_utilizatori
START WITH 1 INCREMENT BY 1 NOCYCLE;

CREATE SEQUENCE seq_comunitati
START WITH 10 INCREMENT BY 10 NOCYCLE;

CREATE SEQUENCE seq_titluri
START WITH 100 INCREMENT BY 1 NOCYCLE;

CREATE SEQUENCE seq_categorii
START WITH 1 INCREMENT BY 1 NOCYCLE;

CREATE SEQUENCE seq_postari
START WITH 1000 INCREMENT BY 1 NOCYCLE;
--[[ ID SEQUENCES ]]--

-- DROP TABLE APRECIERI;
-- DROP TABLE CATEGORII_POSTARI;
-- DROP TABLE DOCUMENTE;
-- DROP TABLE POSTARI;
-- DROP TABLE CATEGORII;
-- DROP TABLE TITLURI_USER;
-- DROP TABLE TITLURI;
-- DROP TABLE USER_COMUNITATE;
-- DROP TABLE COMUNITATI;
-- DROP TABLE URMARITORI;
-- DROP TABLE UTILIZATORI;
--
-- DROP SEQUENCE seq_utilizatori;
-- DROP SEQUENCE seq_comunitati;
-- DROP SEQUENCE seq_titluri;
-- DROP SEQUENCE seq_categorii;
-- DROP SEQUENCE seq_postari;


-- TRIGGERI DE CREATE:
-- X? Data_Creare_Cont - Data_De_Nastere minim 5 ani (incercam check prima oara)
-- X? Pe update Data_Creare_Cont verificam ca toate postarile / comunitatile create
-- sunt create dupa crearea contului

-- X? Pe update insert Aprecieri trebuie ca data_apreciere sa fie dupa crearea postarii si dupa
-- data crearii contului user-ului care acutalizeaza

-- X? Pe update insert user_comunitate trebuie data_intrare sa fie dupa data_creare comunitate
-- si dupa data crearii user-ului

-- X? Pe update insert Postari (Data_Creare_Postare) trebuie sa fie DUPA data_creare_cont a utilizatorului
-- daca util e null ignoram, daca comunnityid nu e null verificam si ca este dupa data_creare_comunitate
-- de asemena, trebuie sa fie INAINTEA primului comentariu si aprecieri

-- X Pe update insert Comunitati (Data_Creare_Comunitate), la insert / update trebuie asigurat ca data_creare_comunitate,
-- este dupa data_creare_cont, la update trebuie verificat ca taote postarile din comunitate sunt create dupa nou data_Creare_comunitate,
-- De asemenea ca toate intrarile in comunitate sunt dupa data crearii

-- o HINT: La categorii sa modificam pg rating cu varsta minima pentru usurinta

-- X Cand intri in comunitate sa inserezi automat in user_comunitate userul cu rolu de admins

-- X trigger pe Utilizatori activ sa aiba upper la fel si la altele de genul.

-- o Pe update insert Titluri_User trebuie verificat ca titlul este dintr-o comunitate din care user-ul face parte

-- || (momentan nu avem cazul de update perfect) Pe delete User_Comunitate trebuie din Titluri_User scoase intrarile invalide si din Postari de facut
-- toate postarile user-ului in aceea comunitate invalide

-- o Comentariile unei postari nu pot avea comunitati.

-- o Pe insert update in postari trebui sa verificam ca user-ul face parte din comunitate
-- o Pe insert update in postari daca postarea are postare_mama_id != null atunci nu poate face parte din vreo comunitate
-- TEST MINIM 5 ANI

    -- [[ UPPER TRIGGERS ]]--
    create or replace trigger TRG_USR_UPPER_ACTIV
    before insert or update of ACTIV on UTILIZATORI
    for each row
    begin
        :NEW.ACTIV := UPPER(:NEW.ACTIV);
    end;

    create or replace trigger  TRG_USR_COM_UPPER_ROLE
    before insert or update of ROL on USER_COMUNITATE
    for each row
    begin
        :NEW.ROL := UPPER(:NEW.ROL);
    end;

    create or replace trigger TRG_TITLURI_UPPER_CULOARE
    before insert or update of CULOARE on TITLURI
    for each row
    begin
        if :NEW.CULOARE is not null then
            :NEW.CULOARE := UPPER(:NEW.CULOARE);
        end if;
    end;

    create or replace trigger TRG_DOC_UPPER_TIP
    before insert or update of DOCUMENT_TIP on DOCUMENTE
    for each row
    begin
        if :NEW.DOCUMENT_TIP is not null then
            :NEW.DOCUMENT_TIP := UPPER(:NEW.DOCUMENT_TIP);
        end if;
    end;
    --[[ UPPER TRIGGERS ]]--

-- NU O MAI FOLOSIM --
create or replace function is_table_accessible(p_table_name in varchar2) return boolean
is
    v_exists number;
begin

    select count(*) into v_exists
    from user_tables
    where table_name = upper(p_table_name);

    if v_exists = 0 then
        return FALSE;
    else
        execute immediate 'select 1 from ' || p_table_name || ' where rownum = 1';
        return TRUE;
    end if;

exception
    when others then
        return FALSE;
end;

--[[ DATE TRIGGERS ]]--
create or replace trigger TRG_USR_DATA_CONT
for update on UTILIZATORI
compound trigger
    type t_usrs is table of number;
    updated_rows t_usrs := t_usrs();

after each row is
begin
    if inserting or :NEW.DATA_CREARE_CONT > :OLD.DATA_CREARE_CONT then
        updated_rows.EXTEND;
        updated_rows(updated_rows.LAST) := :NEW.UTILIZATOR_ID;
    end if;
end after each row;

after statement  is
    creare_cont date;
    lowest_post date;
    lowest_community date;
    lowest_apreciere date;
    lowest_user_comunitate date;
begin
    for i in 1..updated_rows.COUNT loop
        select DATA_CREARE_CONT into creare_cont
        from UTILIZATORI
        where UTILIZATOR_ID = updated_rows(i);

        select MIN(DATA_CREARE_POSTARE) into lowest_post
        from POSTARI
        where CREATOR_ID = updated_rows(i);

        if lowest_post is not null and creare_cont > lowest_post then
                raise_application_error(-20345, 'Cannot change user date when there exists posts with lower dates!');
        end if;

        select MIN(DATA_CREARE_COMUNITATE) into lowest_community
        from COMUNITATI
        where CREATOR_ID = updated_rows(i);

        if lowest_community is not null and creare_cont > lowest_community then
            raise_application_error(-20345, 'Cannot change user date when there exists communities with lower dates!');
        end if;

        select MIN(DATA_APRECIERE) into lowest_apreciere
        from APRECIERI
        where UTILIZATOR_ID = updated_rows(i);

        if lowest_apreciere is not null and creare_cont > lowest_apreciere then
            raise_application_error(-20345, 'Cannot change user date when there exists likes with lower dates!');
        end if;

        select MIN(DATA_INTRARE) into lowest_user_comunitate
        from USER_COMUNITATE
        where MEMBRU_ID = updated_rows(i);

        if lowest_user_comunitate is not null and creare_cont > lowest_user_comunitate then
            raise_application_error(-20345, 'Cannot change user date when there exists entries in communities with lower dates!');
        end if;
    end loop;
end after statement;
end TRG_USR_DATA_CONT;

create or replace trigger TRG_APR_DATA_APR
for insert or update on APRECIERI
compound trigger
    type t_usrs is table of APRECIERI%ROWTYPE;
    updated_rows t_usrs := t_usrs();

after each row is
begin
    if INSERTING or :NEW.DATA_APRECIERE < :OLD.DATA_APRECIERE then
        updated_rows.EXTEND;
        updated_rows(updated_rows.LAST).UTILIZATOR_ID := :NEW.UTILIZATOR_ID;
        updated_rows(updated_rows.LAST).POSTARE_ID := :NEW.POSTARE_ID;
        updated_rows(updated_rows.LAST).DATA_APRECIERE := :NEW.DATA_APRECIERE;
    end if;
end after each row;

after statement is
    post_date date;
    user_date date;
begin
    for i in 1..updated_rows.COUNT loop
        select DATA_CREARE_POSTARE into post_date
        from POSTARI
        where POSTARE_ID = updated_rows(i).POSTARE_ID;

        select DATA_CREARE_CONT into user_date
        from UTILIZATORI
        where UTILIZATOR_ID = updated_rows(i).UTILIZATOR_ID;


        if updated_rows(i).DATA_APRECIERE < user_date then
            raise_application_error(-20345, 'Cannot like a post at a date lower than that of the creation of the user!');
        end if;

        if updated_rows(i).DATA_APRECIERE < post_date then
            raise_application_error(-20345, 'Cannot like a post at a date lower than that of the creation of the post!');
        end if;
    end loop;
end after statement;
end TRG_APR_DATA_APR;

create or replace trigger TRG_USR_COM_DATA_INTRARE
for insert or update of DATA_INTRARE on USER_COMUNITATE
compound trigger
    type t_user_com is table of USER_COMUNITATE%rowtype;
    updated_rows t_user_com := t_user_com();

after each row is
begin
    if INSERTING or :NEW.DATA_INTRARE < :OLD.DATA_INTRARE then
        updated_rows.EXTEND;
        updated_rows(updated_rows.COUNT).MEMBRU_ID := :NEW.MEMBRU_ID;
        updated_rows(updated_rows.COUNT).COMUNITATE_ID := :NEW.COMUNITATE_ID;
        updated_rows(updated_rows.COUNT).DATA_INTRARE := :NEW.DATA_INTRARE;
    end if;
end after each row;

after statement is
    community_date date;
    user_date date;
begin
    for i in 1..updated_rows.COUNT loop

        select DATA_CREARE_COMUNITATE into community_date
        from COMUNITATI
        where COMUNITATE_ID = updated_rows(i).COMUNITATE_ID;

        if updated_rows(i).DATA_INTRARE < community_date then
            raise_application_error(-20345, 'Cannot enter a community before it has been created!');
        end if;

        select DATA_CREARE_CONT into user_date
        from UTILIZATORI
        where UTILIZATOR_ID = updated_rows(i).MEMBRU_ID;

        if updated_rows(i).DATA_INTRARE < user_date then
            raise_application_error(-20345, 'Cannot enter a community before the user has been created!');
        end if;
    end loop;
end after statement;

end TRG_USR_COM_DATA_INTRARE;

--[[
-- Pentru a rezolva problema cu comentarii o sa verificam dupa insert / update ca toate postarile sunt dupa
-- Mother_Post
--]]
-- (de testat schimbarile)
create or replace trigger TRG_POST_DATA_CREARE
for insert or update of DATA_CREARE_POSTARE on POSTARI
compound trigger
    type t_posts is table of postari%rowtype;
    updated_rows t_posts := t_posts();

after each row is
begin
    updated_rows.EXTEND;
    updated_rows(updated_rows.COUNT).POSTARE_ID := :NEW.POSTARE_ID;
    updated_rows(updated_rows.COUNT).CREATOR_ID := :NEW.CREATOR_ID;
    updated_rows(updated_rows.COUNT).COMUNITATE_ID := :NEW.COMUNITATE_ID;
    updated_rows(updated_rows.COUNT).DATA_CREARE_POSTARE := :NEW.DATA_CREARE_POSTARE;
end after each row;

after statement is
    user_date date;
    community_date date;
    like_date date;
    n number;
begin
    for i in 1..updated_rows.COUNT loop

        if updated_rows(i).CREATOR_ID is not null then
            select DATA_CREARE_CONT into user_date
            from UTILIZATORI
            where UTILIZATOR_ID = updated_rows(i).CREATOR_ID;

            if updated_rows(i).DATA_CREARE_POSTARE < user_date then
                raise_application_error(-20345, 'Post cannot be created before user is created!');
            end if;
        end if;

        if updated_rows(i).COMUNITATE_ID is not null then
            select DATA_CREARE_COMUNITATE into community_date
            from COMUNITATI
            where COMUNITATE_ID = updated_rows(i).COMUNITATE_ID;

            if updated_rows(i).DATA_CREARE_POSTARE < community_date then
                raise_application_error(-20345, 'Post cannot be created before community is created!');
            end if;
        end if;


        select MIN(DATA_APRECIERE) into like_date
        from APRECIERI
        where POSTARE_ID = updated_rows(i).POSTARE_ID;

        if like_date is not null and updated_rows(i).DATA_CREARE_POSTARE > like_date then
            raise_application_error(-20345, 'Post cannot be created after it has been liked!');
        end if;

    end loop;

    select count(*) into n
    from POSTARI P1
    join POSTARI P2 on P2.POSTARE_ID = P1.POSTARE_MAMA_ID
    where P1.DATA_CREARE_POSTARE < P2.DATA_CREARE_POSTARE;

    if n > 0 then
        raise_application_error(-20345, 'Post cannot be created after its comments or comments before the post!');
    end if;
end after statement;

end TRG_POST_DATA_CREARE;

create or replace trigger TRG_POST_DATA_COMMENTS
after insert or update of POSTARE_MAMA_ID on POSTARI
declare
    n number;
begin
    select count(*) into n
    from POSTARI P1
    join POSTARI P2 on P2.POSTARE_ID = P1.POSTARE_MAMA_ID
    where P1.DATA_CREARE_POSTARE < P2.DATA_CREARE_POSTARE;

    if n > 0 then
        raise_application_error(-20345, 'Post cannot be created after its comments or comments before the post!');
    end if;
end;

create or replace trigger TRG_POST_DATA_USER
for insert or update of CREATOR_ID on POSTARI
compound trigger
    type t_posts is table of POSTARI%rowtype;
    updated_rows t_posts := t_posts();

after each row is
begin
    if :NEW.CREATOR_ID is not null then
        updated_rows.EXTEND;
        updated_rows(updated_rows.LAST).CREATOR_ID := :NEW.CREATOR_ID;
        updated_rows(updated_rows.LAST).DATA_CREARE_POSTARE := :NEW.DATA_CREARE_POSTARE;
    end if;
end after each row;

after statement is
    user_date date;
begin
    for i in 1..updated_rows.COUNT loop
        select DATA_CREARE_CONT into user_date
        from UTILIZATORI
        where UTILIZATOR_ID = updated_rows(i).CREATOR_ID;

        if updated_rows(i).DATA_CREARE_POSTARE < user_date then
            raise_application_error(-20345, 'Post cannot be created before user is created!');
        end if;
    end loop;
end after statement;

end TRG_POST_DATA_USER;

create or replace trigger TRG_POST_DATA_COMMUNITY
for insert or update of COMUNITATE_ID on POSTARI
compound trigger
    type t_posts is table of POSTARI%rowtype;
    updated_rows t_posts := t_posts();

after each row is
begin
    if :NEW.COMUNITATE_ID is not null then
        updated_rows.EXTEND;
        updated_rows(updated_rows.LAST).COMUNITATE_ID := :NEW.COMUNITATE_ID;
        updated_rows(updated_rows.LAST).DATA_CREARE_POSTARE := :NEW.DATA_CREARE_POSTARE;
    end if;
end after each row;

after statement is
    community_date date;
begin
    for i in 1..updated_rows.COUNT loop
        select DATA_CREARE_COMUNITATE into community_date
        from COMUNITATI
        where COMUNITATE_ID = updated_rows(i).COMUNITATE_ID;

        if updated_rows(i).DATA_CREARE_POSTARE < community_date then
            raise_application_error(-20345, 'Post cannot be created before community is created!');
        end if;
    end loop;
end after statement;

end TRG_POST_DATA_COMMUNITY;

create or replace trigger TRG_COMMUNITY_DATA_CREARE
for insert or update of DATA_CREARE_COMUNITATE on COMUNITATI
compound trigger

    type t_com is table of COMUNITATI%rowtype;
    updated_rows t_com := t_com();

after each row is
begin
    updated_rows.EXTEND;
    updated_rows(updated_rows.COUNT).COMUNITATE_ID := :NEW.COMUNITATE_ID;
    updated_rows(updated_rows.COUNT).CREATOR_ID := :NEW.CREATOR_ID;
    updated_rows(updated_rows.COUNT).DATA_CREARE_COMUNITATE := :NEW.DATA_CREARE_COMUNITATE;
end after each row;

after statement is
    user_date date;
    post_date date;
    user_com_date date;
begin
    for i in 1..updated_rows.COUNT loop

        if updated_rows(i).CREATOR_ID is not null then
            select DATA_CREARE_CONT into user_date
            from UTILIZATORI
            where UTILIZATOR_ID = updated_rows(i).CREATOR_ID;

            if updated_rows(i).DATA_CREARE_COMUNITATE < user_date then
                raise_application_error(-20345, 'Community cannot be created before its creator!');
            end if;
        end if;

        select MIN(DATA_CREARE_POSTARE) into post_date
        from POSTARI
        where COMUNITATE_ID = updated_rows(i).COMUNITATE_ID;

        if post_date is not null and post_date < updated_rows(i).DATA_CREARE_COMUNITATE then
            raise_application_error(-20345, 'Community cannot be created after its posts!');
        end if;

        select MIN(DATA_INTRARE) into user_com_date
        from USER_COMUNITATE
        where COMUNITATE_ID = updated_rows(i).COMUNITATE_ID;

        if user_com_date is not null and user_com_date < updated_rows(i).DATA_CREARE_COMUNITATE then
            raise_application_error(-20345, 'Community cannot be created after its members join date!');
        end if;

    end loop;
end after statement;

end TRG_COMMUNITY_DATA_CREARE;

create or replace trigger TRG_COMMUNITY_DATA_CREATOR
for insert or update of CREATOR_ID on COMUNITATI
compound trigger

    type t_com is table of COMUNITATI%rowtype;
    updated_rows t_com := t_com();

after each row is
begin
    if :NEW.CREATOR_ID is not null then
        updated_rows.EXTEND;
        updated_rows(updated_rows.COUNT).CREATOR_ID := :NEW.CREATOR_ID;
    end if;
end after each row;

after statement is
    user_date date;
begin
    for i in 1..updated_rows.COUNT loop

        select DATA_CREARE_CONT into user_date
        from UTILIZATORI
        where UTILIZATOR_ID = updated_rows(i).CREATOR_ID;

        if updated_rows(i).DATA_CREARE_COMUNITATE < user_date then
            raise_application_error(-20345, 'Community cannot be created before its creator!');
        end if;
    end loop;
end after statement;

end TRG_COMMUNITY_DATA_CREATOR;





--[[ DATE TRIGGERS ]]--

--[[ DATA TRIGGERS ]]--

-- Cand dam insert la comunitati adaugam automat in User_Comunitate la Admin
create or replace trigger TRG_COM_ADMIN
for insert or update of CREATOR_ID on COMUNITATI
compound trigger
    type t_user_com is table of USER_COMUNITATE%rowtype;
    user_com t_user_com := t_user_com();

after each row is
begin
    if :NEW.CREATOR_ID is not null then
        user_com.EXTEND;
        user_com(user_com.LAST).COMUNITATE_ID := :NEW.COMUNITATE_ID;
        user_com(user_com.LAST).MEMBRU_ID := :NEW.CREATOR_ID;
        user_com(user_com.LAST).DATA_INTRARE := SYSDATE;
        user_com(user_com.LAST).ROL := 'ADMIN';
    end if;
end after each row;

after statement is
    creator_exists number;
begin
    for i in 1..user_com.COUNT loop

        select COUNT(MEMBRU_ID) into creator_exists
        from USER_COMUNITATE
        where MEMBRU_ID = user_com(i).MEMBRU_ID and COMUNITATE_ID = user_com(i).COMUNITATE_ID;

        if creator_exists >= 1 then
            update USER_COMUNITATE
            set ROL = 'ADMIN'
            where MEMBRU_ID = user_com(i).MEMBRU_ID and COMUNITATE_ID = user_com(i).COMUNITATE_ID;
        else
            insert into USER_COMUNITATE(MEMBRU_ID, COMUNITATE_ID, ROL, DATA_INTRARE)
            values (user_com(i).MEMBRU_ID, user_com(i).COMUNITATE_ID, user_com(i).ROL, user_com(i).DATA_INTRARE);
        end if;
    end loop;
end after statement;

end TRG_COM_ADMIN;

-- Cand stergem din USER_COMUNITATE vrem sa facem postarile din aceea comunitate sa aiba creator id-ul null
-- de asemenea vrem sa scoatem titluri-le din comunitatea din care iesim
create or replace trigger TRG_USR_COM_DELETE
for delete on USER_COMUNITATE
compound trigger
    type t_usr_com is table of USER_COMUNITATE%rowtype;
    usr_com t_usr_com := t_usr_com();

after each row is
begin
    usr_com.EXTEND;
    usr_com(usr_com.LAST).MEMBRU_ID := :OLD.MEMBRU_ID;
    usr_com(usr_com.LAST).COMUNITATE_ID := :OLD.COMUNITATE_ID;
end after each row;

after statement is
    cursor c_titluri(com_id number) is
        select TITLU_ID
        from TITLURI
        where COMUNITATE_ID = com_id;
begin
    for i in 1..usr_com.COUNT loop
        update POSTARI
        set CREATOR_ID = null
        where CREATOR_ID = usr_com(i).MEMBRU_ID and COMUNITATE_ID = usr_com(i).COMUNITATE_ID;

        for tid in c_titluri(usr_com(i).COMUNITATE_ID) loop
            delete from TITLURI_USER
            where TITLU_ID = tid.TITLU_ID and UTILIZATOR_ID = usr_com(i).MEMBRU_ID;
        end loop;
    end loop;

end after statement;

end TRG_USR_COM_DELETE;

-- Cand adaugam un titlu unui user verificam ca user-ul apartine comunitatii titlului
create or replace trigger TRG_TITL_USR_SAME_COM
before insert or update on TITLURI_USER
for each row
declare
    title_com number;
    is_in_com number;
begin
    select COMUNITATE_ID into title_com
    from TITLURI
    where TITLU_ID = :NEW.TITLU_ID;

    select COUNT(*) into is_in_com
    from USER_COMUNITATE
    where MEMBRU_ID = :NEW.UTILIZATOR_ID and COMUNITATE_ID = title_com;

    if is_in_com = 0 then
        raise_application_error(-20345, 'User cannot own title from a community he is not part of!');
    end if;
end;

-- Cand adaugam o postare sau updatam creator_id-ul sau community id-ul trebuie sa verificam
-- ca creator-ul face parte din comunitate
create or replace trigger TRG_POST_USR_COM
for insert or update of CREATOR_ID, COMUNITATE_ID on POSTARI
compound trigger
    type t_uc_querry is table of USER_COMUNITATE%rowtype;
    uc_querry t_uc_querry := t_uc_querry();
after each row is
begin
    if :NEW.CREATOR_ID is not null and :NEW.COMUNITATE_ID is not null then
        uc_querry.EXTEND;
        uc_querry(uc_querry.LAST).MEMBRU_ID := :NEW.CREATOR_ID;
        uc_querry(uc_querry.LAST).COMUNITATE_ID := :NEW.COMUNITATE_ID;
    end if;
end after each row;

after statement is
    n number;
begin
    for i in 1..uc_querry.COUNT loop
        select COUNT(*) into n
        from USER_COMUNITATE
        where MEMBRU_ID = uc_querry(i).MEMBRU_ID and COMUNITATE_ID = uc_querry(i).COMUNITATE_ID;

        if n = 0 then
            raise_application_error(-20345, 'Cannot put post in a community the user is not part of!');
        end if;
    end loop;
end after statement;

end TRG_POST_USR_COM;

-- Comentariile unei postari nu pot face parte din comunitati
create or replace trigger TRG_POST_COMMENTS_NO_COM
before insert or update of COMUNITATE_ID, POSTARE_MAMA_ID on POSTARI
for each row
begin
    if :NEW.POSTARE_MAMA_ID is not null and :NEW.COMUNITATE_ID is not null then
        raise_application_error(-20345, 'Comments cannot be part of a community!');
    end if;
end;



--[[ DATA TRIGGERS ]]--

