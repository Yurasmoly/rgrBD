-- Створюємо базу даних, видаляючи попередню, якщо вона існує 
DROP SCHEMA IF EXISTS music_school;
CREATE SCHEMA music_school;
-- Вказуємо, що ми будемо працювати з цією БД 
USE music_school;
-- Посада
CREATE TABLE position (
    position_id INT PRIMARY KEY AUTO_INCREMENT, -- Первинний ключ з авто-інкрементом 
    position_name VARCHAR(100) NOT NULL, -- Текстове поле, обов'язкове 
    salary DECIMAL(10, 2), -- Десяткове число 
    duties TEXT -- Поле для довгого опису 
);
-- Учень
CREATE TABLE student (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    passport_id VARCHAR(20) UNIQUE, -- Поле з унікальним значенням 
    phone_number VARCHAR(20),
    grade_level VARCHAR(10) -- "№ класу"
);

-- Клас 
CREATE TABLE classroom (
    classroom_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    capacity INT,
    type VARCHAR(50)
);

-- Предмет
CREATE TABLE subject (
    subject_id INT PRIMARY KEY AUTO_INCREMENT,
    subject_name VARCHAR(100) NOT NULL,
    difficulty_level VARCHAR(50)
);

-- Створюємо залежні таблиці (Secondary Tables)

-- Вчитель (залежить від 'position')
CREATE TABLE teacher (
    teacher_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    address VARCHAR(255),
    birth_date DATE, -- Тип "дата" 
    gender CHAR(1),
    position_id INT -- Поле для зовнішнього ключа
);

-- Музичний інструмент (залежить від 'teacher' )
CREATE TABLE instrument (
    instrument_id INT PRIMARY KEY AUTO_INCREMENT,
    manufacture_date DATE,
    cost DECIMAL(10, 2),
    teacher_id INT -- Поле для зовнішнього ключа (відношення "Взаємодіє")
);

-- Заняття (залежить від 'teacher', 'classroom', 'subject')
CREATE TABLE lesson (
    lesson_id INT PRIMARY KEY AUTO_INCREMENT,
    teacher_id INT NOT NULL,
    classroom_id INT NOT NULL,
    subject_id INT NOT NULL,
    lesson_time DATETIME -- Тип "дата і час" 
);

-- Створюємо таблиці-зв'язки для відношень M:M (Many-to-Many)

-- "Відвідує" (Зв'язок M:M між 'lesson' та 'student')
CREATE TABLE lesson_attendance (
    lesson_id INT,
    student_id INT,
    PRIMARY KEY (lesson_id, student_id) -- Складений первинний ключ 
);

-- "Присутній" (Зв'язок M:M між 'student' та 'subject')
CREATE TABLE student_subject_enrollment (
    student_id INT,
    subject_id INT,
    PRIMARY KEY (student_id, subject_id)
);

-- "Використовує" (Зв'язок M:M між 'subject' та 'instrument')
CREATE TABLE subject_instrument (
    subject_id INT,
    instrument_id INT,
    PRIMARY KEY (subject_id, instrument_id)
);

-- "Знаходиться" (Зв'язок M:M між 'classroom' та 'instrument')
CREATE TABLE classroom_instrument (
    classroom_id INT,
    instrument_id INT,
    PRIMARY KEY (classroom_id, instrument_id)
);
-- ДОДАВАННЯ ЗОВНІШНІХ КЛЮЧІВ
-- Вчитель -> Посада
ALTER TABLE teacher
    ADD FOREIGN KEY (position_id) REFERENCES position (position_id);

-- Інструмент -> Вчитель ("Взаємодіє")
ALTER TABLE instrument
    ADD FOREIGN KEY (teacher_id) REFERENCES teacher(teacher_id);

-- Заняття -> Вчитель, Клас, Предмет
ALTER TABLE lesson
    ADD FOREIGN KEY (teacher_id) REFERENCES teacher(teacher_id),
    ADD FOREIGN KEY (classroom_id) REFERENCES classroom(classroom_id),
    ADD FOREIGN KEY (subject_id) REFERENCES subject(subject_id);

-- 'lesson_attendance' -> Заняття, Учень
ALTER TABLE lesson_attendance
    ADD FOREIGN KEY (lesson_id) REFERENCES lesson(lesson_id),
    ADD FOREIGN KEY (student_id) REFERENCES student(student_id);

-- 'student_subject_enrollment' -> Учень, Предмет
ALTER TABLE student_subject_enrollment
    ADD FOREIGN KEY (student_id) REFERENCES student(student_id),
    ADD FOREIGN KEY (subject_id) REFERENCES subject(subject_id);

-- 'subject_instrument' -> Предмет, Інструмент
ALTER TABLE subject_instrument
    ADD FOREIGN KEY (subject_id) REFERENCES subject(subject_id),
    ADD FOREIGN KEY (instrument_id) REFERENCES instrument(instrument_id);

-- 'classroom_instrument' -> Клас, Інструмент
ALTER TABLE classroom_instrument
    ADD FOREIGN KEY (classroom_id) REFERENCES classroom(classroom_id),
    ADD FOREIGN KEY (instrument_id) REFERENCES instrument(instrument_id);
   
