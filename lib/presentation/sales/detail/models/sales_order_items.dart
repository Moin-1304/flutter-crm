import 'sales_product.dart';

class OrderItem {
  String? productId;
  int? qty;
  double? rate;
  String? uom;
  DateTime? reqDate;
  int? bonusQty;
  int? addlBonusQty;
  String? notes;

  OrderItem({
    this.productId,
    this.qty = 1,
    this.rate,
    this.uom,
    this.reqDate,
    this.bonusQty = 0,
    this.addlBonusQty = 0,
    this.notes = '',
  });

  factory OrderItem.fromProduct(Product p, {int qty = 1, DateTime? reqDate, int bonusQty = 0, int addlBonusQty = 0, String notes = ''}) {
    return OrderItem(
      productId: p.id,
      qty: qty,
      rate: p.rate,
      uom: p.uom,
      reqDate: reqDate,
      bonusQty: bonusQty,
      addlBonusQty: addlBonusQty,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'qty': qty,
    'rate': rate,
    'uom': uom,
    'reqDate': reqDate?.toIso8601String(),
    'bonusQty': bonusQty,
    'addlBonusQty': addlBonusQty,
    'notes': notes,
  };
}
