const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');
const app = express();

// 1. Configuración de la carpeta Web
const webFolder = path.join(__dirname, 'build', 'web');

// Servir archivos estáticos
app.use(express.static(webFolder));

// --- CAMBIO IMPORTANTE AQUÍ ---
// En lugar de '*', usamos /.*/ (Expresión Regular)
// Esto arregla el error "PathError" en versiones nuevas de Express
app.get(/.*/, (req, res) => {
    res.sendFile(path.join(webFolder, 'index.html'));
});
// ------------------------------

const PORT = 443;

try {
    // 2. Cargar Certificados (Asegúrate de que la carpeta 'certs' esté ahí)
    const httpsOptions = {
        key: fs.readFileSync(path.join(__dirname, 'certs', 'programastablet.ddns.net-key.pem')),
        cert: fs.readFileSync(path.join(__dirname, 'certs', 'programastablet.ddns.net-crt.pem')),
        ca: fs.readFileSync(path.join(__dirname, 'certs', 'programastablet.ddns.net-chain.pem'))
    };

    https.createServer(httpsOptions, app).listen(PORT, () => {
        console.log(`🌍 PÁGINA WEB SEGURA lista en puerto ${PORT}`);
        console.log(`👉 Entrar en: https://programastablet.ddns.net:${PORT}`);
    });

} catch (error) {
    console.error("❌ Error con certificados en la WEB:", error.message);
    console.log("⚠️ Verifica que tengas la carpeta 'certs' dentro de la carpeta de Flutter.");
}