USE music_school;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS DenormalizedMusicSchool;
DROP TABLE IF EXISTS position;
DROP TABLE IF EXISTS teacher;
DROP TABLE IF EXISTS Student_1NF;
DROP TABLE IF EXISTS Teacher_Position_1NF;
DROP TABLE IF EXISTS lesson_attendance;

CREATE TABLE DenormalizedMusicSchool (
    record_id INT PRIMARY KEY AUTO_INCREMENT,
    -- Інформація про вчителя та посаду (транзитивна залежність)
    teacher_name VARCHAR(150),
    position_name VARCHAR(100),
    salary DECIMAL(10, 2), 
    duties TEXT,
    
    -- Інформація про інструмент 
    instrument_name VARCHAR(100), 
    instrument_cost DECIMAL(10,2),
    
    -- Інформація про учня та заняття 
    student_info JSON, -- Неатомарні дані
    lesson_time DATETIME
);

-- Заповнення тестовими даними
INSERT INTO DenormalizedMusicSchool (teacher_name, position_name, salary, duties, instrument_name, instrument_cost, student_info, lesson_time)
VALUES 
('Іваненко Петро', 'Викладач вищої категорії', 15000.00, 'Викладання, методика', 'Фортепіано Yamaha', 50000.00, '{"name": "Петров Олексій", "grade": "5"}', '2025-05-10 14:00:00'),
('Іваненко Петро', 'Викладач вищої категорії', 15000.00, 'Викладання, методика', 'Рояль Steinway', 120000.00, '{"name": "Сидорова Анна", "grade": "3"}', '2025-05-10 15:00:00'),
('Коваль Марія', 'Концертмейстер', 12000.00, 'Акомпанемент', 'Скрипка Stradivari-copy', 30000.00, '{"name": "Петров Олексій", "grade": "5"}', '2025-05-11 10:00:00');



-- Перехід до Першої Нормальної Форми (1NF)
-- Таблиця учнів (атомарні значення)
CREATE TABLE Student_1NF (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150),
    grade_level VARCHAR(10)
);

-- Таблиця вчителів та їх посад 
CREATE TABLE Teacher_Position_1NF (
    teacher_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150),
    position_name VARCHAR(100),
    salary DECIMAL(10, 2) -- Проблема: зарплата залежить від посади, а не від ID вчителя
);

CREATE TABLE lesson_attendance (
    lesson_id INT,
    student_id INT,
    PRIMARY KEY (lesson_id, student_id)
    -- Тут немає зайвих полів типу student_name, тільки ключі
);

-- Таблиця посад (Position) - усуваємо транзитивну залежність
CREATE TABLE position (
    position_id INT PRIMARY KEY AUTO_INCREMENT,
    position_name VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2),
    duties TEXT
);

-- Таблиця вчителів (Teacher) - посилається на position_id
CREATE TABLE teacher (
    teacher_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    address VARCHAR(255),
    birth_date DATE,
    gender CHAR(1),
    position_id INT,
    FOREIGN KEY (position_id) REFERENCES position (position_id)
);
DROP USER IF EXISTS 'music_director'@'localhost';
CREATE USER 'music_director'@'localhost' IDENTIFIED BY 'director_pass';
CREATE USER 'music_teacher'@'localhost' IDENTIFIED BY 'teacher_pass';
CREATE USER 'music_reception'@'localhost' IDENTIFIED BY 'reception_pass';
CREATE USER 'music_accountant'@'localhost' IDENTIFIED BY 'money_pass';

SELECT user, host FROM mysql.user WHERE user LIKE 'music_%';

GRANT ALL PRIVILEGES ON music_school.* TO 'music_director'@'localhost';

GRANT SELECT, INSERT, UPDATE ON music_school.student TO 'music_reception'@'localhost';
SHOW GRANTS FOR 'music_teacher'@'localhost';

GRANT SELECT, INSERT, DELETE ON music_school.student_subject_enrollment TO 'music_reception'@'localhost';
SHOW GRANTS FOR 'music_reception'@'localhost';

USE music_school;

CREATE VIEW TeacherSchedule AS 
SELECT l.lesson_time, c.name as classroom, s.subject_name 
FROM lesson l 
JOIN classroom c ON l.classroom_id = c.classroom_id
JOIN subject s ON l.subject_id = s.subject_id;
GRANT SELECT ON music_school.TeacherSchedule TO 'music_teacher'@'localhost';
-- 1. Перевірка, що права надані 
SHOW GRANTS FOR 'music_teacher'@'localhost';
-- 2. Перевірка, що саме View працює коректно (має показати табличку з розкладом)
SELECT * FROM music_school.TeacherSchedule;

GRANT SELECT (instrument_id, manufacture_date, teacher_id) ON music_school.instrument TO 'music_teacher'@'localhost';
SHOW GRANTS FOR 'music_teacher'@'localhost';

GRANT SELECT, UPDATE ON music_school.position TO 'music_accountant'@'localhost';
SHOW GRANTS FOR 'music_accountant'@'localhost';

GRANT EXECUTE ON music_school.* TO 'music_director'@'localhost';
SHOW GRANTS FOR 'music_director'@'localhost';

-- Спочатку надамо для тесту
GRANT DELETE ON music_school.student TO 'music_reception'@'localhost';
-- Тепер забираємо
REVOKE DELETE ON music_school.student FROM 'music_reception'@'localhost';
SHOW GRANTS FOR 'music_reception'@'localhost';

REVOKE UPDATE (duties) ON music_school.position FROM 'music_accountant'@'localhost';
SHOW GRANTS FOR 'music_accountant'@'localhost';

REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'music_teacher'@'localhost';
SHOW GRANTS FOR 'music_teacher'@'localhost';

SHOW GRANTS FOR 'music_director'@'localhost';
SHOW GRANTS FOR 'music_reception'@'localhost';
USE music_school;
GRANT CREATE TEMPORARY TABLES ON music_school.* TO 'music_accountant'@'localhost';
SHOW GRANTS FOR 'music_accountant'@'localhost';
-- 2. Практичний тест 
-- Заходимо як бухгалтер і створюємо тимчасову таблицю
CREATE TEMPORARY TABLE music_school.CalculationCache (
    calc_id INT,
    temp_total DECIMAL(10,2)
);
-- 3. Перевірка, що вона створилась 
DESCRIBE music_school.CalculationCache;
-- 4. Прибирання за собою 
DROP TEMPORARY TABLE IF EXISTS music_school.CalculationCache;

DROP USER 'music_director'@'localhost';
DROP USER 'music_teacher'@'localhost';
DROP USER 'music_reception'@'localhost';
DROP USER 'music_accountant'@'localhost';

DELIMITER $$

CREATE PROCEDURE AddStudentSafe(
    IN p_full_name VARCHAR(150),
    IN p_passport_id VARCHAR(20),
    IN p_phone VARCHAR(20),
    IN p_grade VARCHAR(10)
)
BEGIN
    -- Оголошення обробника дублікатів
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        SELECT CONCAT('Помилка: Учень з паспортом ', p_passport_id, ' вже існує!') AS ErrorMessage;
    END;

    INSERT INTO student (full_name, passport_id, phone_number, grade_level)
    VALUES (p_full_name, p_passport_id, p_phone, p_grade);
    
    SELECT 'Учня успішно додано.' AS Result;
END$$

DELIMITER ;

-- 1. Дивимось, які учні вже є (запам'ятовуємо passport_id, наприклад 'ID123456')
SELECT * FROM student;

-- 2. Спроба додати дублікат (Має вивести повідомлення про помилку замість системного крашу)
CALL AddStudentSafe('Тестовий Клон', 'ID123456', '0990000000', '1 клас');

DELIMITER $$

CREATE PROCEDURE ScheduleLesson(
    IN p_teacher_id INT,
    IN p_classroom_id INT,
    IN p_subject_id INT,
    IN p_time DATETIME
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Помилка: Неможливо запланувати урок. Перевірте ID вчителя, класу або предмету.' AS Error;
    END;

    START TRANSACTION;
        INSERT INTO lesson (teacher_id, classroom_id, subject_id, lesson_time)
        VALUES (p_teacher_id, p_classroom_id, p_subject_id, p_time);
        
        SELECT 'Урок заплановано.' AS Success;
    COMMIT;
END$$

DELIMITER ;

-- Спроба призначити урок вчителю з ID 999 (якого не існує)
-- Очікуємо повідомлення: "Помилка: Неможливо запланувати урок..."
CALL ScheduleLesson(999, 1, 1, '2025-09-01 10:00:00');


DELIMITER $$
-- 2. Видаляємо старий тригер, якщо він вже існує (щоб уникнути помилок при повторному запуску)
DROP TRIGGER IF EXISTS BeforePositionUpdate$$
CREATE TRIGGER BeforePositionUpdate
BEFORE UPDATE ON `position`
FOR EACH ROW
BEGIN
    -- Перевірка: якщо нова зарплата менша за 0
    IF NEW.salary < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Помилка: Зарплата не може бути меншою за 0!';
    END IF;
END$$
DELIMITER ;
-- Спроба встановити від'ємну зарплату.
-- Цей запит має викликати помилку і НЕ оновити дані.
UPDATE `position` SET salary = -5000 WHERE position_id = 1;

DELIMITER $$

CREATE PROCEDURE CalcTeacherInventory(IN p_teacher_id INT)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_cost DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2) DEFAULT 0;
    
    -- Курсор для вибору інструментів вчителя
    DECLARE cur CURSOR FOR SELECT cost FROM instrument WHERE teacher_id = p_teacher_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO v_cost;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        IF v_cost IS NOT NULL THEN
            SET v_total = v_total + v_cost;
        END IF;
    END LOOP;

    CLOSE cur;
    
    SELECT v_total AS TotalInventoryValue;
END$$

DELIMITER ;
-- 1. Перевіримо, які інструменти є у вчителя з ID 1
SELECT * FROM instrument WHERE teacher_id = 1;

-- 2. Викликаємо процедуру (має повернути суму вартості цих інструментів)
CALL CalcTeacherInventory(1);

DELIMITER $$

CREATE TRIGGER CheckRoomAvailability
BEFORE INSERT ON lesson
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM lesson WHERE classroom_id = NEW.classroom_id AND lesson_time = NEW.lesson_time) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Помилка: Цей клас зайнятий у вказаний час!';
    END IF;
END$$

DELIMITER ;
-- 1. Призначаємо перший урок (Успішно)
INSERT INTO lesson (teacher_id, classroom_id, subject_id, lesson_time)
VALUES (1, 1, 1, '2025-10-10 12:00:00');

-- 2. Спроба призначити другий урок ТУДИ Ж і в ТОЙ ЖЕ ЧАС (Помилка)
-- Очікуємо червону помилку: "Помилка: Цей клас зайнятий..."
INSERT INTO lesson (teacher_id, classroom_id, subject_id, lesson_time)
VALUES (2, 1, 2, '2025-10-10 12:00:00');

DELIMITER $$

CREATE PROCEDURE DeleteSubjectSafe(IN p_subject_id INT)
BEGIN
    -- Оголошуємо обробник помилки 1451 (неможливо видалити батьківський запис)
    DECLARE EXIT HANDLER FOR 1451
    BEGIN
        SELECT 'Помилка: Неможливо видалити предмет, оскільки на нього записані учні!' AS ErrorMessage;
    END;

    -- Спроба видалення
    DELETE FROM subject WHERE subject_id = p_subject_id;
    
    -- Якщо видалення успішне
    SELECT 'Предмет успішно видалено з бази.' AS Result;
END$$

DELIMITER ;

-- 1. Підготовка: Переконаємося, що у нас є предмет і учень, записаний на нього
-- Створимо предмет "Бандура", якщо немає
INSERT INTO subject (subject_name, difficulty_level) VALUES ('Бандура', 'Hard');
-- Отримаємо ID цього предмету (припустимо, це останній доданий)
SET @subj_id = LAST_INSERT_ID();
-- Запишемо учня (ID 1) на цей предмет
INSERT INTO student_subject_enrollment (student_id, subject_id) VALUES (1, @subj_id);

-- 2. ТЕСТ НА ПОМИЛКУ: Спроба видалити предмет "Бандура"
--  ви побачите наше повідомлення: "Помилка: Неможливо видалити предмет..."
CALL DeleteSubjectSafe(@subj_id);

-- 3. ТЕСТ НА УСПІХ: Спочатку відпишемо учня, потім видалимо
DELETE FROM student_subject_enrollment WHERE subject_id = @subj_id;
CALL DeleteSubjectSafe(@subj_id);

USE music_school;
DROP PROCEDURE IF EXISTS SearchTeacherDynamic;

DELIMITER $$

CREATE PROCEDURE SearchTeacherDynamic(IN p_search_term VARCHAR(50))
BEGIN
    -- Формуємо текст запиту
    SET @query = CONCAT('SELECT * FROM teacher WHERE full_name LIKE CONCAT("%", ?, "%") OR phone_number LIKE CONCAT("%", ?, "%")');
    -- Готуємо вираз
    PREPARE stmt FROM @query;
    -- Встановлюємо параметри 
    SET @term = p_search_term;
    EXECUTE stmt USING @term, @term;
    
    -- Очищаємо пам'ять
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Додаємо тестові дані 
INSERT INTO position (position_name, salary) VALUES ('Викладач', 15000.00);
INSERT INTO teacher (full_name, phone_number, position_id) 
VALUES ('Петренко Іван', '0671112233', LAST_INSERT_ID());

-- 2. Тепер викликаємо пошук
CALL SearchTeacherDynamic('Петр');
CALL SearchTeacherDynamic('067');


DROP PROCEDURE IF EXISTS FilterInstruments;
DELIMITER $$

CREATE PROCEDURE FilterInstruments(IN p_min_cost DECIMAL(10,2))
BEGIN
    -- Якщо параметр NULL, показуємо все. Інакше - фільтруємо.
    IF p_min_cost IS NULL THEN
        SET @query = 'SELECT * FROM instrument';
    ELSE
        SET @query = CONCAT('SELECT * FROM instrument WHERE cost >= ', p_min_cost);
    END IF;

    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Варіант "Показати все" (передаємо NULL)
CALL FilterInstruments(NULL);

-- 2. Варіант "Тільки дорогі" (передаємо 40000)
CALL FilterInstruments(40000);

DROP PROCEDURE IF EXISTS ListStudentsSorted;
DELIMITER $$

CREATE PROCEDURE ListStudentsSorted(IN p_sort_column VARCHAR(50))
BEGIN
    -- Формуємо запит із підставленим ім'ям колонки
    SET @query = CONCAT('SELECT * FROM student ORDER BY ', p_sort_column);
    
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Сортування за ІМЕНЕМ (алфавітний порядок)
CALL ListStudentsSorted('full_name');

-- 2. Сортування за КЛАСОМ (групування по класах)
CALL ListStudentsSorted('grade_level');

DROP PROCEDURE IF EXISTS DynamicDelete;
DELIMITER $$

CREATE PROCEDURE DynamicDelete(
    IN p_table_name VARCHAR(64),
    IN p_id_col_name VARCHAR(64),
    IN p_id_value INT
)
BEGIN
    SET @query = CONCAT('DELETE FROM ', p_table_name, ' WHERE ', p_id_col_name, ' = ?');
    
    PREPARE stmt FROM @query;
    SET @id = p_id_value;
    EXECUTE stmt USING @id;
    DEALLOCATE PREPARE stmt;
    
    SELECT CONCAT('Запис з ID ', p_id_value, ' успішно видалено з таблиці ', p_table_name) AS Status;
END$$

DELIMITER ;

-- 1. Створимо фейкового учня для тесту
INSERT INTO student (full_name, passport_id, phone_number, grade_level) 
VALUES ('Учень На Видалення', 'DEL001', '000', '1 клас');
SET @del_id = LAST_INSERT_ID();

-- 2. Викликаємо процедуру видалення (Передаємо: таблиця 'student', колонка 'student_id', ID учня)
CALL DynamicDelete('student', 'student_id', @del_id);

-- 3. Перевіряємо, що учня більше немає (має бути порожньо)
SELECT * FROM student WHERE full_name = 'Учень На Видалення';

DROP PROCEDURE IF EXISTS SelectSpecificColumns;
DELIMITER $$

CREATE PROCEDURE SelectSpecificColumns(
    IN p_table_name VARCHAR(64),
    IN p_columns VARCHAR(255) -- список колонок через кому, наприклад 'full_name, phone_number'
)
BEGIN
    SET @query = CONCAT('SELECT ', p_columns, ' FROM ', p_table_name);
    
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Хочемо бачити назву інструменту та його ціну
CALL SelectSpecificColumns('instrument', 'instrument_id, cost');

DROP PROCEDURE IF EXISTS CountRowsDynamic;
DELIMITER $$

CREATE PROCEDURE CountRowsDynamic(IN p_table_name VARCHAR(64))
BEGIN
    SET @query = CONCAT('SELECT COUNT(*) AS Total_Rows FROM ', p_table_name);
    
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Скільки у нас учнів?
CALL CountRowsDynamic('student');

-- 2. Скільки у нас інструментів?
CALL CountRowsDynamic('instrument');

DROP PROCEDURE IF EXISTS GetTopNRecords;
DELIMITER $$

CREATE PROCEDURE GetTopNRecords(
    IN p_table_name VARCHAR(64),
    IN p_sort_col VARCHAR(64),
    IN p_limit INT
)
BEGIN
    -- Сортуємо за спаданням (DESC)
    SET @query = CONCAT('SELECT * FROM ', p_table_name, ' ORDER BY ', p_sort_col, ' DESC LIMIT ?');
    
    PREPARE stmt FROM @query;
    SET @lim = p_limit;
    EXECUTE stmt USING @lim;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- 1. Показати 2 найдорожчі інструменти (сортуємо по cost)
CALL GetTopNRecords('instrument', 'cost', 2);

-- 2. Показати 3 останні створені посади (сортуємо по position_id)
CALL GetTopNRecords('position', 'position_id', 3);

DROP PROCEDURE IF EXISTS BackupTableDynamic;
DELIMITER $$

CREATE PROCEDURE BackupTableDynamic(
    IN p_source_table VARCHAR(64),
    IN p_backup_name VARCHAR(64)
)
BEGIN
    -- Видаляємо бекап, якщо він вже був (щоб не було помилки)
    SET @drop_query = CONCAT('DROP TABLE IF EXISTS ', p_backup_name);
    PREPARE stmt1 FROM @drop_query;
    EXECUTE stmt1;
    DEALLOCATE PREPARE stmt1;

    -- Створюємо нову таблицю на основі старої
    SET @create_query = CONCAT('CREATE TABLE ', p_backup_name, ' AS SELECT * FROM ', p_source_table);
    
    PREPARE stmt2 FROM @create_query;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;
    
    SELECT CONCAT('Таблицю ', p_source_table, ' скопійовано у ', p_backup_name) AS Result;
END$$

DELIMITER ;

-- 1. Робимо бекап таблиці посад (position) у таблицю 'position_backup_2025'
CALL BackupTableDynamic('position', 'position_backup_2025');

-- 3. (Для порядку) Можна видалити цей бекап
DROP TABLE position_backup_2025;