IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'ArduinoDB')
BEGIN

CREATE DATABASE ArdunioDB;
END
GO

CREATE TABLE Sensors(
SensorID INT IDENTITY(1,1) primary key,
	SensorName nVARCHAR(50) not null,
	SensorType VARCHAR(50) not null,
	Location VARCHAR(100)
);
GO

create table Girdiler(
id bigint identity(1,1) primary key,
sensorID int not null,
Sicaklik FLOAT not null,
nem FLOAT not null,
İsikLux FLOAT not null,
RecordedAt DATETIME2 NOT NULL 
CONSTRAINT DF_Girdiler_RecordedAt DEFAULT (SYSUTCDATETIME())
CONSTRAINT FK_Girdiler_Sensors FOREIGN KEY (SensorID) 
REFERENCES Sensors(SensorID) ON DELETE CASCADE
);
GO



CREATE INDEX IX_Girdiler_RecordedAt ON Girdiler(RecordedAt);
GO