import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/jwt-auth.guard';

describe('TransactionsController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context: { switchToHttp: () => { getRequest: () => { user?: { userId: string } } } }) => {
          const request = context.switchToHttp().getRequest();
          request.user = { userId: 'user-1' };
          return true;
        },
      })
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/transactions (POST, GET, GET summary)', async () => {
    const payload = {
      title: 'Salario',
      amount: 5100,
      type: 'income',
      category: 'Trabalho',
      occurredAt: '2026-05-01T10:00:00.000Z',
    };

    await request(app.getHttpServer())
      .post('/transactions')
      .set('Authorization', 'Bearer test-token')
      .send(payload)
      .expect(201)
      .expect((response) => {
        expect(response.body.title).toBe(payload.title);
        expect(response.body.userId).toBe('user-1');
      });

    await request(app.getHttpServer())
      .get('/transactions')
      .set('Authorization', 'Bearer test-token')
      .expect(200)
      .expect((response) => {
        expect(response.body).toHaveLength(1);
      });

    await request(app.getHttpServer())
      .get('/transactions/summary?month=2026-05')
      .set('Authorization', 'Bearer test-token')
      .expect(200)
      .expect((response) => {
        expect(response.body).toMatchObject({
          month: '2026-05',
          income: 5100,
          expense: 0,
          balance: 5100,
          entriesCount: 1,
          exitsCount: 0,
        });
      });
  });

  afterEach(async () => {
    await app.close();
  });
});