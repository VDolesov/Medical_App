const swaggerJsdoc = require('swagger-jsdoc');

const swaggerOptions = {
  definition: {   // Исправлено!
    openapi: '3.0.0',
    info: {
      title: 'Medical App API',
      version: '1.0.0',
      description: 'API для загрузки и анализа медицинских анализов',
    },
    servers: [
      { url: 'http://localhost:5000' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 1 },
            username: { type: 'string', example: 'doctor1' },
            email: { type: 'string', example: 'doctor1@mail.ru' },
            first_name: { type: 'string', example: 'Иван' },
            last_name: { type: 'string', example: 'Иванов' },
            role: { type: 'string', example: 'doctor' },
          }
        },
        Norm: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 3 },
            name: { type: 'string', example: 'Кальций общий' },
            min_value: { type: 'number', example: 2.15 },
            max_value: { type: 'number', example: 2.6 },
            unit: { type: 'string', example: 'ммоль/л' }
          }
        },
        ReportMeta: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 17 },
            user_id: { type: 'integer', example: 2 },
            file_name: { type: 'string', example: 'test_data.xlsx' },
            created_at: { type: 'string', example: '2025-06-17T11:22:13.131Z' }
          }
        },
        Report: {
          type: 'object',
          properties: {
            code: { type: 'string', example: '001' },
            age: { type: 'integer', example: 34 },
            outOfNorms: {
              type: 'array',
              items: {
                oneOf: [
                  {
                    type: 'object',
                    properties: {
                      analysis: { type: 'string', example: 'ТТГ' },
                      value: { type: 'number', example: 4.1 },
                      min: { type: 'number', example: 0.4 },
                      max: { type: 'number', example: 4.0 },
                      unit: { type: 'string', example: 'мЕд/л' },
                      status: { type: 'string', example: 'выше нормы' }
                    }
                  },
                  {
                    type: 'string',
                    example: 'Все значения в норме'
                  }
                ]
              }
            }
          }
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string', example: 'Сообщение об ошибке' }
          }
        }
      }
    },
    security: [{ bearerAuth: [] }]
  },
  apis: ['./routes/*.js'], // если роуты разнесены по разным файлам
};

const swaggerDocs = swaggerJsdoc(swaggerOptions);

module.exports = { swaggerDocs };
