import mysql from 'mysql2';

const connection = mysql.createConnection({
  host: 'database-1.ctugoi66ae9m.ap-south-1.rds.amazonaws.com',
  port: 3306,
  user: 'admin',
  password: 'Vishal#1615!',
});

connection.connect((error) => {
  if (error) {
    console.error('Connection FAILED:', error.message);
    console.error('Error Code:', error.code);
  } else {
    console.log('Connection SUCCESSFUL!');
    connection.end();
  }
});
