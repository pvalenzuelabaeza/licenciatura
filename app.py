from flask import Flask, request, render_template, redirect, url_for, flash
import config
from flask_mysqldb import MySQL

app = Flask(__name__)

app.config['MYSQL_HOST'] = config.MYSQL_HOST
app.config['MYSQL_USER'] = config.MYSQL_USER
app.config['MYSQL_PASSWORD'] = config.MYSQL_PASSWORD
app.config['MYSQL_DB'] = config.MYSQL_DB

app.secret_key = "mysecretkey"

mysql = MySQL(app)

@app.route('/')
def login():
    return render_template('login.html')

@app.route('/board')
def board():
    cur = mysql.connection.cursor()
    cur.execute('select S.Nombre,L.Tipo,Estado,L.Descripcion from \
        (select * from Memoria union select * from Espacio) as L,Servidor as S \
        where L.ip=S.ip')
    data = cur.fetchall()
    cur.execute('select L.Estado, count(*) from (select * from Memoria union select * from Espacio) as L group by L.Estado order by 1')
    datEstados = cur.fetchall()
    cur.execute('select * from Servidor')
    cserver = cur.fetchall()
    return render_template('dboard.html', dboards = data, cser = cserver, destado = datEstados)

@app.route('/soper')
def soper():
    cur = mysql.connection.cursor()
    cur.execute('select * from SisOper')
    data = cur.fetchall()
    return render_template('operativo.html', sopers = data)

@app.route('/script')
def script():
    cur = mysql.connection.cursor()
    cur.execute('select op.Descripcion,sc.Codigo,sc.Nombre,sc.Descripcion from Script as sc, SisOper as op where op.Kernel = sc.Kernel')
    data = cur.fetchall()
    cur.execute('select * from SisOper')
    dataSo = cur.fetchall()
    return render_template('scripts.html', scripts = data, listSo = dataSo)

@app.route('/server')
def server():
    cur = mysql.connection.cursor()
    cur.execute('select * from Servidor')
    data = cur.fetchall()
    cur.execute('select * from SisOper')
    dataSo = cur.fetchall()
    return render_template('servidores.html',servers = data, listSo = dataSo)

@app.route('/add_script', methods=['POST'])
def add_script():
    if request.method == 'POST':
        vSoper = request.form['selOperativo']
        vCodigo = request.form['txtCodigo']
        vNombre = request.form['txtNombre']
        vDescribe = request.form['txtDescribe']

        try:
            cur = mysql.connection.cursor()
            cur.execute(
                "INSERT INTO Script VALUES (%s,%s,%s,%s)", (vSoper, vCodigo, vNombre, vDescribe))
            mysql.connection.commit()
            #flash('Script Agregado')
            return redirect(url_for('script'))
        except Exception as e:
            flash(e.args[1])
            return redirect(url_for('script'))

@app.route('/delscript/<string:cod>')
def delete_script(cod):
    cur = mysql.connection.cursor()
    cur.execute(
        "DELETE FROM Script WHERE Codigo = {0}".format(cod))
    mysql.connection.commit()
    return redirect(url_for('script'))

@app.route('/edscript/<cod>')
def edit_script(cod):
    cur = mysql.connection.cursor()
    cur.execute('select op.Descripcion,sc.Codigo,sc.Nombre,sc.Descripcion from Script as sc, SisOper as op where op.Kernel = sc.Kernel')
    dataSc = cur.fetchall()
    cur.execute('select * from SisOper')
    dataSo = cur.fetchall()
    cur.execute("SELECT * FROM Script WHERE Codigo = %s",cod)
    data = cur.fetchall()
    return render_template('edscripts.html', scdata = data[0], scripts = dataSc, listSo = dataSo)

@app.route('/upscript/<cod>', methods=['POST'])
def update_script(cod):
    if request.method == 'POST':
        vSoper = request.form['selOperativo']
        vCodigo = request.form['txtCodigo']
        vNombre = request.form['txtNombre']
        vDescribe = request.form['txtDescribe']
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE Script
            SET Kernel = %s,
                Codigo = %s,
                Nombre = %s,
                Descripcion = %s
            WHERE Codigo = %s
            """, (vSoper, vCodigo, vNombre, vDescribe, cod))
        mysql.connection.commit()
        return redirect(url_for('script'))


if __name__ == '__main__':
    app.run(debug=True)
