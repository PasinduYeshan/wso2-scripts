var Request = require('tedious').Request;
var Connection = require('tedious').Connection;
const fs = require('fs')
const async = require('async');

const dbScriptPath = process.argv[2];
const dbPassword = process.argv[3];
const identityDBName = process.argv[4];
const sharedDBName = process.argv[5];
const dbPort = process.argv[6];

console.log('dbPort', dbPort);

var dbCreateSQL = `
IF EXISTS(SELECT * FROM sys.databases WHERE name = N'${identityDBName}')
    DROP DATABASE ${identityDBName};
CREATE DATABASE ${identityDBName};

IF EXISTS(SELECT * FROM sys.databases WHERE name = N'${sharedDBName}')
    DROP DATABASE ${sharedDBName};
CREATE DATABASE ${sharedDBName};
`;

var spliter = `GO
`

function createConfig(database) {

    var config = {
        server: 'localhost',
        authentication: {
            type: 'default',
            options: {
                userName: 'db2inst1',
                password: `${dbPassword}`
            }
        },
        options: {
            encrypt: true,
            database: database,
            trustServerCertificate: true,
            port: Number(dbPort)
        }
    };
    return config
}

function executeStatement(sqlScript, connection) {

    request = new Request(sqlScript, function (err) {
        if (err) {
            console.log(err);
        }
    });

    request.on('done', function (rowCount, more) {
        console.log('Request Done');
    });

    // Close the connection after the final event emitted by the request, after the callback passes.
    request.on("requestCompleted", function (rowCount, more) {
        connection.close();
    });

    connection.execSql(request);
}

function createDatabase() {

    var connection = new Connection(createConfig("master"));
    connection.on('connect', function (err) {
        if (err) {
            console.log(err);

            return;
        }
        // If no error, then good to proceed.
        console.log("Connected");
        executeStatement(dbCreateSQL, connection);
    });

    connection.connect();
    return "done"
}

async function executeDBScripts(dbName, dbScripts) {
    for (let index = 0; index < dbScripts.length; index++) {
        const sqlFile = dbScripts[index];
        var data = await fs.readFileSync(sqlFile, 'utf8')
        data = data.split(spliter)
        console.log("Executing the script " + sqlFile + " in " + dbName)
        for (let i = 0; i < data.length; i++) {
            var connection = new Connection(createConfig(dbName));
            await sleep(2000);
            connection.on('connect', function (err) {
                // If no error, then good to proceed.
                console.log("Connected to database " + dbName);
                if (data[i] != '') {
                    executeStatement(data[i], connection);
                }
            });
            connection.connect();
            await sleep(2000);
        }
    }
    return "done"
}

async function executeScriptsOnDB() {

    const identityDBScripts = [
        dbScriptPath + "/identity/db2.sql",
        dbScriptPath + "/consent/db2.sql",
    ]
    const sharedDBScripts = [
        dbScriptPath + "/db2.sql",
    ]

   await executeDBScripts(identityDBName, identityDBScripts)
   await executeDBScripts(sharedDBName, sharedDBScripts)
}

function sleep(ms) {

    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

async function run_processes() {

    await createDatabase();
    await executeScriptsOnDB();
    process.exit(0)
}

run_processes();
