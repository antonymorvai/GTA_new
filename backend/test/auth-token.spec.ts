import { AuthService } from '../src/auth/auth.service';
import { UnauthorizedException } from '@nestjs/common';

describe('AuthService JWT', () => {
  const service = new AuthService({} as never, {} as never);

  beforeAll(() => {
    process.env.JWT_SECRET = 'test-secret-nur-fuer-unit-tests';
  });

  it('signiert und verifiziert einen Token (Roundtrip)', () => {
    const token = service.signToken({ sub: 42, username: 'tester' });
    const payload = service.verifyToken(token);
    expect(payload.sub).toBe(42);
    expect(payload.username).toBe('tester');
  });

  it('lehnt manipulierte Tokens ab', () => {
    const token = service.signToken({ sub: 42, username: 'tester' });
    const tampered = token.slice(0, -4) + 'AAAA';
    expect(() => service.verifyToken(tampered)).toThrow(UnauthorizedException);
  });

  it('lehnt Tokens mit falschem Secret ab', () => {
    const token = service.signToken({ sub: 1, username: 'x' });
    process.env.JWT_SECRET = 'anderes-secret';
    expect(() => service.verifyToken(token)).toThrow(UnauthorizedException);
    process.env.JWT_SECRET = 'test-secret-nur-fuer-unit-tests';
  });
});
