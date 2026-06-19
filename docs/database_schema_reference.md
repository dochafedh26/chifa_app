# Database Schema Reference
# Generated from clinic.sql

## Key Tables and Their Columns

### patients (18 columns)
- patient_id, first_name, last_name, gender, date_of_birth, phone, atcd, source, email, national_id, address, created_at, status, uuid, updated_at, is_deleted, needs_sync, source_id

### appointments (11 columns)
- appointment_id, patient_id, doctor_id, appointment_date, status, notes, uuid, updated_at, is_deleted, needs_sync, source_id

### medicalrecords (19 columns)
- record_id, patient_id, doctor_id, record_date, motif, details, diagnostic, prescriptions, weight, temperature, tension_arterielle, frequence_cardiaque, spao2, record_timer, uuid, updated_at, is_deleted, needs_sync, source_id

### invoices (13 columns)
- invoice_id, patient_id, appointment_id, total_amount, payment_method, status, issue_date, due_date, uuid, updated_at, is_deleted, needs_sync, source_id

### payments (14 columns)
- payment_id, patient_id, doctor_id, patient_name, patient_surname, services, total_amount, payment_date, note, record_id, payment_method, uuid, updated_at, is_deleted, needs_sync, source_id

### bilans (10 columns)
- id, patient_id, doctor_id, bilans, created_at, uuid, updated_at, is_deleted, needs_sync, source_id

### arret_de_travail (14 columns)
- id, patient_id, doctor_id, type, motif, date_debut, jours, date_reprise, date_creation, uuid, updated_at, is_deleted, needs_sync, source_id

### duty_reports (10 columns)
- id, doctor_id, report_date, status, created_at, uuid, updated_at, is_deleted, needs_sync, source_id

### certificat_bonne_sante (10 columns)
- id, patient_id, doctor_id, created_at, updated_at, uuid, is_deleted, needs_sync, source_id

### certificat_dispension_sport (11 columns)
- id, patient_id, doctor_id, motif, created_at, updated_at, uuid, is_deleted, needs_sync, source_id

### certificat_maladie_chronique (11 columns)
- id, patient_id, doctor_id, maladie_chronique, created_at, updated_at, uuid, is_deleted, needs_sync, source_id

### inventory (14 columns)
- item_id, item_name, category, quantity, unit_price, expiration_date, purchase_date, supplier_name, created_at, uuid, updated_at, is_deleted, needs_sync, source_id

### lettres (12 columns)
- id, patient_id, doctor_id, atcd, motif_consultation, examen_clinique, motif_lettre, created_at, uuid, updated_at, is_deleted, needs_sync, source_id

### soins_medicaux (10 columns)
- id, patient_id, doctor_id, soins, medicalrecord_id, created_at, uuid, updated_at, is_deleted, needs_sync, source_id

### soins_services (6 columns)
- id, nom, uuid, updated_at, is_deleted, needs_sync, source_id

### modern_prescriptions (6 columns)
- id, prescription, uuid, updated_at, is_deleted, needs_sync, source_id

## Common Columns (in all tables)
- uuid (varchar 36)
- updated_at (timestamp)
- is_deleted (tinyint 1)
- needs_sync (tinyint 1)
- source_id (varchar 50)