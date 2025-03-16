const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const resetPasswordRoutes = require('./resetpassword');
const deleteAccountRoutes = require('./deleteaccount');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// API Routes
app.use('/api/password', resetPasswordRoutes);
app.use('/api/account', deleteAccountRoutes);

// Ana sayfa - API bilgisi
app.get('/', (req, res) => {
  res.json({
    message: 'Günübirlik API Sunucusu',
    endpoints: {
      passwordReset: {
        sendCode: '/api/password/send-reset-code',
        verifyCode: '/api/password/verify-reset-code',
        resetPassword: '/api/password/reset-password'
      },
      accountManagement: {
        deleteAccount: {
          sendCode: '/api/account/send-delete-code',
          verifyCode: '/api/account/verify-delete-code',
          deleteAccount: '/api/account/delete-account'
        }
      }
    }
  });
});

// Sunucuyu başlat
app.listen(PORT, () => {
  console.log(`API Sunucusu ${PORT} portunda çalışıyor`);
  console.log(`API'ye erişmek için: http://localhost:${PORT}`);
}); 