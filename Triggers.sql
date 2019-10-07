USE ApuestasDeportivas
--USE master
--En la tabla ingresos cuando se hace un insert hay que hacer un trigger que aumente el saldo del usuario 
--(Cuando se retira también funcionaria igual).
GO
CREATE TRIGGER modificarSaldo ON Ingresos
AFTER INSERT AS
	BEGIN
		UPDATE Usuarios
		SET saldo = U.saldo + I.cantidad
		FROM Usuarios AS U
		INNER JOIN inserted AS I ON U.id = I.id_usuario
		WHERE U.id = I.id_usuario
	END
GO

-- Cuando una apuesta está en la BBDD, no se puede eliminar ni modificar. Un trigger ayudaría
GO
CREATE TRIGGER noModificarApuestas ON Apuestas
INSTEAD OF DELETE, UPDATE AS
	--BEGIN
		THROW 51000, 'La apuesta no se puede ni modificar ni eliminar cuando ya se ha realizado', 1
		ROLLBACK
	--END
GO

-- Para poder apostar, el tiempo del partido debe estar abierto (que la fecha de la apuesta este entre fechaHoraInicio y 
--fechaHoraFin del partido), trigger o procedimiento almacenado (no estoy seguro)
CREATE TRIGGER partidoAbiertoApuesta ON Apuestas
AFTER INSERT AS 
	BEGIN
		IF EXISTS (SELECT * FROM inserted AS I
		INNER JOIN Partidos AS P ON I.id_partido = P.id
		WHERE I.fechaHora NOT BETWEEN DATEADD(DAY, -2, P.fechaInicio) AND P.fechaFin) 
		BEGIN
			RAISERROR ('La apuesta para ese partido no ha empezado o se ha cerrado', 16,1)
			ROLLBACK
		END
	END


--Procedimiento que comprueba que una apuesta es ganada o no
GO
CREATE PROCEDURE comprobarApuestaAcertada @idApuesta INT, @tipo TINYINT
AS
BEGIN
DECLARE @acertada BIT
SET @acertada = 0
	IF(@tipo = 1)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		INNER JOIN Apuestas_tipo1 AS A1 ON  A1.id = A.id
		WHERE A1.golLocal = P.golLocal AND A1.golVisitante = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END

	IF(@tipo = 2)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		INNER JOIN Apuestas_tipo2 AS A2 ON  A2.id = A.id
		WHERE A2.puja = '1' AND A2.gol = P.golLocal OR A2.puja = '2' AND A2.gol = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END

	IF(@tipo = 3)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		INNER JOIN Apuestas_tipo3 AS A3 ON  A3.id = A.id
		WHERE A3.puja = '1' AND P.golLocal > P.golVisitante OR A3.puja = '2' AND P.golLocal < P.golVisitante OR A3.puja = 'x' AND P.golLocal = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END
	RETURN @acertada
END
GO

GO

/*
Trigger que no se pueda modificar despues de concluir la finalizacion del partido
*/
GO
CREATE TRIGGER partidoFinalizado ON Partidos
AFTER UPDATE AS 
	BEGIN
		IF EXISTS (SELECT * FROM inserted AS I
		INNER JOIN Partidos AS P ON I.id = P.id
		--INNER JOIN deleted AS D ON P.id = D.id
		WHERE GETDATE() > DATEADD(MINUTE, -10, P.fechaFin)) 
		BEGIN
			RAISERROR ('El partido se ha cerrado y no se permite mas modificaciones', 16,1)
			ROLLBACK
		END
	END
GO

/*
	Trigger que no se pueda antes de empezar el partido modificar el marcador
*/
GO
CREATE TRIGGER modificarMarcador ON Partidos
AFTER UPDATE, INSERT AS 
	BEGIN
		IF EXISTS (SELECT * FROM inserted AS I
		INNER JOIN Partidos AS P ON I.id = P.id
		--INNER JOIN deleted AS D ON P.id = D.id
		WHERE GETDATE() < DATEADD(DAY, -2, P.fechaInicio) AND I.golLocal > 0 AND I.golVisitante > 0) 
		BEGIN
			RAISERROR ('El partido no ha empezado o los goles deben ser 0 a 0', 16,1)
			ROLLBACK
		END
	END
GO

--1er Trigger actualiza el saldo del usuario cuando realiza una apuesta
GO	
CREATE OR ALTER TRIGGER actualizarSaldo on Apuestas
AFTER INSERT AS
	BEGIN
		DECLARE @saldo money
		DECLARE @cantidad int
		DECLARE @id_usuario smallint 
		SELECT @saldo = U.saldo, @cantidad=I.cantidad, @id_usuario=U.id FROM Usuarios AS U 
		INNER JOIN inserted AS I ON U.id = I.id_usuario

		
		IF(@cantidad > @saldo)
			BEGIN
				RAISERROR('No tiene suficiente saldo',16,1)
				ROLLBACK
			END
		ELSE
			BEGIN
				UPDATE Usuarios
				SET saldo -= @cantidad WHERE id=@id_usuario
				--Insertamos el ingreso
				INSERT INTO Ingresos (cantidad, descripcion, id_usuario) VALUES (@cantidad,'Apuesta realizada',@id_usuario)
			END
	END
GO

/*
	Comprobar los beneficios maximos para no dejar pagar la apuesta
*/

-- Se comprueba que en cada apuesta ganada no se supere el maximo beneficio definido en la tabla
-- Si esto ocurre, el pago de la apuesta quedaria anulada
CREATE PROCEDURE noSePagaMaximo @IDApuesta SMALLINT, @Tipo TINYINT 
AS
BEGIN
	IF(@Tipo = 1)
	BEGIN
		IF EXISTS(SELECT * FROM Apuestas AS A
		INNER JOIN Apuestas_tipo1 AS AT1 ON A.id = AT1.id
		WHERE AT1.apuestasMáximas < A.cantidad * A.cuota)
		BEGIN
			ROLLBACK
		END
	END

	IF(@Tipo = 2)
	BEGIN
		IF EXISTS(SELECT * FROM Apuestas AS A
		INNER JOIN Apuestas_tipo2 AS AT2 ON A.id = AT2.id
		WHERE AT2.apuestasMáximas < A.cantidad * A.cuota)
		BEGIN
			ROLLBACK
		END
	END

	IF(@Tipo = 3)
	BEGIN
		IF EXISTS(SELECT * FROM Apuestas AS A
		INNER JOIN Apuestas_tipo3 AS AT3 ON A.id = AT3.id
		WHERE AT3.apuestasMáximas < A.cantidad * A.cuota)
		BEGIN
			ROLLBACK
		END
	END
END

--Este procedimiento es sumar la apuesta en caso de que este acertada
GO
CREATE PROCEDURE sumarApuesta 
				 @IDApuesta int,
				 @IDUsuario int
AS
BEGIN
	declare @salgoGanado int
	declare @acertada bit
	declare @tipo tinyint

	set @tipo = (Select tipo FROM Apuestas WHERE ID = @IDApuesta)
	SELECT @acertada = fn.comprobarApuestaAcertada(@IDApuesta,@tipo)
	SELECT @acertada = fn.comprobarNoSupereLimite(@IDApuesta)

	IF(@acertada = 1)
	BEGIN
		
		SELECT @salgoGanado = saldo + (cantidad*cuota) FROM Apuestas AS A
		INNER JOIN Usuarios AS U
			ON U.id = A.id_usuario
		WHERE @IDApuesta = A.id AND @IDUsuario = id_usuario
		
		/*UPDATE Usuarios 
		SET saldo = @salgoGanado
		WHERE id = @IDUsuario*/
		 
		INSERT INTO Ingresos (cantidad,descripcion,id_usuario)
		SELECT @salgoGanado,'apuesta ganada',@IDUsuario

	END
END
GO


--Inserts

INSERT INTO Usuarios
VALUES (500,'aabb@gmail.com','1234'),(5000,'bbb@gmail.com','5678'),(8000,'gmasd@gmail.com','9123')

INSERT INTO Ingresos (cantidad,descripcion,id_usuario)
VALUES (300,'Ingreso',1),(-300,'Reintegro',2),(2000,'Ingreso',3)

INSERT INTO Partidos 
VALUES(3,2,'12-01-2019 12:00','12-01-2019 13:45','Sevilla','Betis'),(0,5,'13-01-2019 13:00','13-01-2019 14:45','Carmona','Coria'),
(2,2,'03-03-2019 22:00','03-03-2019 23:45','Barcelona','Madrid')

INSERT INTO Apuestas
VALUES (1.2,50,1,'11-01-2019 12:00',1,1),(2.0,20,1,'12-01-2019 12:00',2,2),(2.50,300,1,'02-03-2019 12:00',3,3)

INSERT INTO Apuestas_tipo1
VALUES (1,500,3,2)

INSERT INTO Apuestas_tipo2
VALUES (2,1000,5,'2')

INSERT INTO Apuestas_tipo3
VALUES (3,10000,'x')