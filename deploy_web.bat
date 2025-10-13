@echo off
echo 🚀 Iniciando deploy do app web "Onde Parei?" para Firebase Hosting
echo.

cd onde_parei

echo 📦 Verificando build...
if not exist "build\web" (
    echo ❌ Build não encontrado! Execute 'flutter build web --release' primeiro
    pause
    exit /b 1
)

echo ✅ Build encontrado. Continuando...
echo.

echo 🔐 Fazendo login no Firebase (se necessário)...
firebase login --reauth
echo.

echo 🚀 Fazendo deploy...
firebase deploy --only hosting
echo.

echo 🎉 Deploy concluido!
echo.
echo 🌐 Seu app está online em: https://onde-parei-ea32c.web.app
echo.

echo 📋 Próximos passos:
echo 1. Compartilhe o link: https://onde-parei-ea32c.web.app
echo 2. Mostre suas manhwas e livros coreanos para os amigos
echo 3. Aproveite a busca ultra-rápida!
echo.

pause
