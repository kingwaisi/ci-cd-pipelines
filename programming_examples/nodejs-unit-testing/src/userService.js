// Asynchroner Code mit einer Abhängigkeit (z.B. Datenbank oder API).
// Die Abhängigkeit wird über den Konstruktor übergeben ("Dependency Injection"),
// damit wir sie im Test durch einen Mock ersetzen können.

export class UserService {
  constructor(userRepository) {
    this.userRepository = userRepository;
  }

  async getDisplayName(userId) {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new Error(`User ${userId} nicht gefunden`);
    }
    return `${user.firstName} ${user.lastName}`;
  }
}
