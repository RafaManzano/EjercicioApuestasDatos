--1er Trigger actualiza el saldo del usuario cuando realiza una apuesta
GO	
CREATE OR ALTER TRIGGER actualizarSaldo on Apuestas
AFTER INSERT AS
	BEGIN
		DECLARE @saldo money
		DECLARE @cantidad money
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
			/*
				UPDATE Usuarios
				SET saldo -= @cantidad WHERE id=@id_usuario
			*/
				--Insertamos el ingreso
				set @cantidad *=-1
				INSERT INTO Ingresos (cantidad, descripcion, id_usuario) VALUES (@cantidad,'Apuesta realizada',@id_usuario)
			END
	END
GO



