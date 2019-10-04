USE ApuestasDeportivas
Go
-----------------------------------------------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------------------------------------------------------
INSERT INTO Usuarios 
Values(500,'asfsad@gmail.com','1234'),(10000,'bbbbb@gmail.com','5678'),(50000,'aaaab@gmail.com','9123')

INSERT INTO Ingresos
SELECT 200,'ingreso',id
FROM Usuarios AS U
WHERE U.id = 1

INSERT INTO Ingresos
SELECT -300,'reintegro',id
FROM Usuarios AS U
WHERE U.id = 2

INSERT INTO Ingresos
SELECT 500,'ingreso',id
FROM Usuarios AS U
WHERE U.id = 3

INSERT INTO Partidos
Values (0,0)

