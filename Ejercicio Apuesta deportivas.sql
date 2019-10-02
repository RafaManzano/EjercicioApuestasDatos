--Ejercicio de acceso de datos sobre las apuestas deportivas.
--Los intengrantes del grupo son: Rafa manzano, victor perez, y miguel espigares.
--
--USE master
CREATE DATABASE ApuestasDeportivas
Go
USE ApuestasDeportivas
Go

--DROP DATABASE ApuestasDeportivas
CREATE TABLE Usuarios(
	id smallint identity not null  constraint pk_id_usuarios primary key, 
	--------------------------------------------------------------------------
	saldo money not null
		constraint ck_Usuarios_saldo check(saldo >= 0),
	correo varchar(30) null,
		constraint ck_Usuarios_correo check(correo LIKE '%@%'),
	contraseña varchar(25) not null
)

CREATE TABLE Partidos(
	id smallint identity not null constraint pk_id_partidos primary key,
	--------------------------------------------------------------------------
	golLocal tinyint not null
		constraint ck_partidos_golLocal check (golLocal >= 0),
	golVisitante tinyint not null
		constraint ck_partidos_golVisitante check (golVisitante >= 0),
	apuestasMáximas money not null
		constraint ck_partidos_apuestasMáximas check (apuestasMáximas > 0),
	fechaInicio SMALLDATETIME not null,
	fechaFin SMALLDATETIME not null,
	nombreLocal varchar(20) not null,
	nombreVisitante varchar(20) not null,
)

CREATE TABLE Ingresos(
	id smallint identity not null constraint pk_id_ingresos primary key,
	--------------------------------------------------------------------------
	cantidad int not null,
	descripcion varchar(15) null,
	id_usuario smallint not null,
	constraint fk_id_usuario_Ingresos foreign key (id_usuario) references Usuarios(id)
)

CREATE TABLE Apuestas(
	id smallint identity not null constraint pk_id_apuestas primary key,
	--------------------------------------------------------------------------
	cuota decimal(5,2) not null
		constraint ck_Apuestas_cuota check(cuota > 1),
	cantidad money not null
		constraint ck_Apuestas_cantidad check(cantidad > 0),
	tipo tinyint not null
		constraint ck_Apuestas_tipo check(tipo in ('1','2','3')),
	puja char(1) null
		constraint ck_Apuestas_puja check(puja in ('1','x','2')),
	golLocal tinyint null
		constraint ck_Apuestas_golLocal check(golLocal >= 0),
	golVisitante tinyint null
		constraint ck_Apuestas_golVisitante check(golVisitante >= 0),
	fechaHora SMALLDATETIME not null,
	--------------------------------------------------------------------------
	id_usuario smallint not null
	constraint fk_id_usuarios foreign key (id_usuario) references Usuarios(id),
	id_partido smallint not null
	constraint fk_id_partidos foreign key (id_partido) references Partidos(id)
)
