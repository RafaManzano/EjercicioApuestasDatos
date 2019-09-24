USE ApuestasDeportivas

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