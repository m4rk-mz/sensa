-- Sensa: esquema de base de datos (PostgreSQL / Supabase)
-- Ejecutar en el SQL Editor de Supabase antes de levantar el backend.
-- Orden: 01_schema.sql -> scripts/seed_admin.py -> 02_pruebas.sql (opcional, demo)
-- En una BD creada antes del 24 nov 2026, correr también 03_acciones_nodo.sql.

-- ---------------------------------------------------------------------------
-- Extensiones
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('platform_admin', 'business_user');
exception when duplicate_object then null; end $$;

do $$ begin
  create type command_action as enum ('led_on', 'led_off', 'auto');
exception when duplicate_object then null; end $$;
-- Acciones agregadas después (ver 03_acciones_nodo.sql en una BD ya creada).
alter type command_action add value if not exists 'alerta';
alter type command_action add value if not exists 'probar_leds';

do $$ begin
  create type command_status as enum ('pendiente', 'enviado', 'confirmado', 'sin_respuesta');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------
create table if not exists businesses (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null check (char_length(trim(nombre)) between 2 and 120),
  creado_en   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- users
-- El rol vive en la BD: nunca se toma del formulario.
-- Invariante: el administrador de plataforma no pertenece a un negocio.
-- ---------------------------------------------------------------------------
create table if not exists users (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null check (char_length(trim(nombre)) between 2 and 120),
  email          text not null unique check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  password_hash  text not null,
  rol            user_role not null default 'business_user',
  business_id    uuid references businesses(id) on delete cascade,
  activo         boolean not null default true,
  creado_en      timestamptz not null default now(),
  constraint users_rol_business_coherente check (
    (rol = 'platform_admin' and business_id is null)
    or (rol = 'business_user' and business_id is not null)
  )
);
create index if not exists users_business_idx on users(business_id);

-- ---------------------------------------------------------------------------
-- devices (nodos ESP32)
-- token_hash: hash Argon2id del secreto del dispositivo. El token en claro
-- se muestra una sola vez, al registrar el sensor.
-- ---------------------------------------------------------------------------
create table if not exists devices (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references businesses(id) on delete cascade,
  nombre         text not null check (char_length(trim(nombre)) between 2 and 120),
  token_hash     text not null,
  umbral_c       numeric(4,1) not null default 27.0 check (umbral_c between 0 and 50),
  -- Modo manual del LED: si manual_hasta > now(), manda el estado forzado.
  modo_manual_hasta  timestamptz,
  led_forzado        boolean,
  led_estado_real    boolean not null default false,
  ultima_lectura_en  timestamptz,
  activo         boolean not null default true,
  creado_en      timestamptz not null default now()
);
create index if not exists devices_business_idx on devices(business_id);

-- ---------------------------------------------------------------------------
-- readings
-- Rangos del DHT11 (datasheet): 0 a 50 C, 20 a 90 % HR.
-- La BD NO tiene CHECK de rango aquí (a propósito, para la prueba 5): el
-- backend valida al leer, así que un registro insertado a mano fuera de
-- rango nunca llega a la app.
-- ---------------------------------------------------------------------------
create table if not exists readings (
  id            uuid primary key default gen_random_uuid(),
  device_id     uuid not null references devices(id) on delete cascade,
  temperatura   numeric(4,1) not null,
  humedad       numeric(4,1) not null,
  led_reportado boolean not null default false,
  alerta        boolean not null default false,
  creado_en     timestamptz not null default now()
);
create index if not exists readings_device_fecha_idx on readings(device_id, creado_en desc);

-- ---------------------------------------------------------------------------
-- actuator_commands
-- ---------------------------------------------------------------------------
create table if not exists actuator_commands (
  id             uuid primary key default gen_random_uuid(),
  device_id      uuid not null references devices(id) on delete cascade,
  accion         command_action not null,
  estado         command_status not null default 'pendiente',
  requested_by   uuid references users(id) on delete set null,
  creado_en      timestamptz not null default now(),
  enviado_en     timestamptz,
  confirmado_en  timestamptz
);
create index if not exists commands_device_idx on actuator_commands(device_id, creado_en desc);

-- ---------------------------------------------------------------------------
-- daily_reports
-- ---------------------------------------------------------------------------
create table if not exists daily_reports (
  id                uuid primary key default gen_random_uuid(),
  device_id         uuid not null references devices(id) on delete cascade,
  fecha             date not null,
  temp_min          numeric(4,1) not null,
  temp_max          numeric(4,1) not null,
  temp_prom         numeric(4,1) not null,
  hum_prom          numeric(4,1) not null,
  lecturas_validas  integer not null default 0,
  alertas           integer not null default 0,
  activaciones_led  integer not null default 0,
  generado_en       timestamptz not null default now(),
  unique (device_id, fecha)
);

-- ---------------------------------------------------------------------------
-- Seguridad de acceso directo
-- El backend usa la service_role key y aplica los permisos en los
-- controladores (arquitectura MC). Se activa RLS sin políticas para que
-- la anon key no pueda leer nada desde fuera del backend.
-- ---------------------------------------------------------------------------
alter table businesses        enable row level security;
alter table users             enable row level security;
alter table devices           enable row level security;
alter table readings          enable row level security;
alter table actuator_commands enable row level security;
alter table daily_reports     enable row level security;
