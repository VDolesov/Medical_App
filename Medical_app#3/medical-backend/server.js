const app = require('./app');
const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`Medical backend started on port ${PORT}`);
});
