CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS analysis_reports (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    file_name VARCHAR(255),
    report_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_reports_user
      FOREIGN KEY (user_id) REFERENCES users(id)
      ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS patients (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    age INTEGER,
    sex VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS analysis_norms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    min_value DOUBLE PRECISION NOT NULL,
    max_value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS analysis_results (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    norm_id INTEGER NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    date TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_results_patient
      FOREIGN KEY (patient_id) REFERENCES patients(id)
      ON DELETE CASCADE,
    CONSTRAINT fk_results_norm
      FOREIGN KEY (norm_id) REFERENCES analysis_norms(id)
      ON DELETE CASCADE
);



INSERT INTO analysis_norms (id, name, min_value, max_value, unit) VALUES
(1, 'Щелочная фосфатаза', 30.0, 120.0, 'Ед/л'),
(2, 'Кальций общий', 2.15, 2.6, 'ммоль/л'),
(3, 'ТТГ', 0.4, 4.0, 'мЕд/л'),
(4, 'Т4 свободный', 9.0, 22.0, 'пмоль/л'),
(5, 'Кальцитонин', 0.0, 10.0, 'пг/мл'),
(6, 'Паратгормон', 15.0, 65.0, 'пг/мл'),
(7, 'Антитела к тиреоглобулину', 0.0, 115.0, 'МЕ/мл'),
(8, 'РЭА', 0.0, 5.0, 'нг/мл'),
(9, 'Щелочная фосфатаза после операции', 30.0, 120.0, 'Ед/л'),
(10, 'Кальций общий после операции', 2.15, 2.6, 'ммоль/л'),
(11, 'ТТГ после операции', 0.4, 4.0, 'мЕд/л'),
(12, 'Т4 после операции', 9.0, 22.0, 'пмоль/л'),
(13, 'Кальцитонин после операции', 0.0, 10.0, 'пг/мл'),
(14, 'Паратгормон после операции', 15.0, 65.0, 'пг/мл'),
(15, 'Антитела к тиреоглобулину после операции', 0.0, 115.0, 'МЕ/мл'),
(16, 'РЭА после операции', 0.0, 5.0, 'нг/мл');


INSERT INTO users (id, username, password_hash, email, first_name, last_name, role) VALUES
(1, 'kos1', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjYsInJvbGUiOiJkb2N0b3IiLCJpYXQiOjE3NTAyMDM3NDUsImV4cCI6MTc1MDIzMjU0NX0.LZBsynHElLkpwnXP26rmpsNNoNvOS07AhLcyOZ9QXh0', 'kos1@mail.ru', 'Костя', 'Доля', 'doctor'),
(2, 'admin', '$2b$10$pl.X60MzDhiACK/k/QWqcetOv0UKn0zY5Dr6CVHQuVwNUVX0BsPXm', 'Val_dolesov@mail.ru', 'Валентин', 'Долесов', 'admin'),
(3, 'val1', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjUsInJvbGUiOiJkb2N0b3IiLCJpYXQiOjE3NTAyMDM1MTIsImV4cCI6MTc1MDIzMjMxMn0.SIfTKX26kBCxc-mntMlYhZyeDI81nRAZuvJyPOFo-OM', 'val1@mail.ru', 'Андрей', 'Петров', 'doctor');
