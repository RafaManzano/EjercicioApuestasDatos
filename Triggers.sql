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
		WHERE I.fechaHora NOT BETWEEN P.fechaInicio AND P.fechaFin) 
		BEGIN
			RAISERROR ('La apuesta para ese partido no ha empezado o se ha cerrado', 16,1)
			ROLLBACK
		END
	END


--Procedimiento que comprueba que una apuesta es ganada o no
GO
CREATE PROCEDURE comprobarApuestaAcertada @idApuesta INT, @tipo INT
AS
BEGIN
DECLARE @acertada BIT
SET @acertada = 0
	IF(@tipo = 1)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		WHERE A.golLocal = P.golLocal AND A.golVisitante = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END

	IF(@tipo = 2)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		WHERE A.puja = '1' AND A.golLocal = P.golVisitante OR A.puja = '2' AND A.golVisitante = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END

	IF(@tipo = 3)
	BEGIN
		IF EXISTS (SELECT * FROM Apuestas AS A
		INNER JOIN Partidos AS P ON A.id_partido = P.id AND A.id = @idApuesta
		WHERE A.puja = '1' AND P.golLocal > P.golVisitante OR A.puja = '2' AND P.golLocal < P.golVisitante OR A.puja = 'x' AND P.golLocal = P.golVisitante)
		BEGIN
			SET @acertada = 1
		END
	END
	RETURN @acertada
END
GO