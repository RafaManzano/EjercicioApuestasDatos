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

INSERT INTO Usuarios
VALUES (500,'aabb@gmail.com','1234'),(5000,'')