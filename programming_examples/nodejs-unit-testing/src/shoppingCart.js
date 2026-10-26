// Eine Klasse mit Zustand – zeigt beforeEach und das Testen von Objekten

export class ShoppingCart {
  constructor() {
    this.items = [];
  }

  addItem(name, price, quantity = 1) {
    if (price < 0) {
      throw new Error("Preis darf nicht negativ sein");
    }
    this.items.push({ name, price, quantity });
  }

  removeItem(name) {
    this.items = this.items.filter((item) => item.name !== name);
  }

  getTotal() {
    return this.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  }

  applyDiscount(percent) {
    return this.getTotal() * (1 - percent / 100);
  }
}
