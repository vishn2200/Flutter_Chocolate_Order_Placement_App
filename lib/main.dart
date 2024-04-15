import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:image/image.dart' as imgLib;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      appId: '1:1019437904153:android:7fbdbf047b33212b391588',
      apiKey: 'AIzaSyBUz0zCKFIj0H9rsceg_L55HMbRnG2Q8U0',
      projectId: 'orderapp-7090e',
      messagingSenderId: '1019437904153',
      authDomain: 'orderapp-7090e.firebaseapp.com',
      databaseURL: 'https://orderapp-7090e.firebaseio.com',
    ),
  );

  runApp(OrderApp());
}

class OrderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Order App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: OrderScreen(),
    );
  }
}

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Map<String, int> quantities = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Place Order'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ProductList(quantities: quantities),
          ),
          OrderButton(quantities: quantities),
        ],
      ),
    );
  }
}

class ProductList extends StatelessWidget {
  final Map<String, int> quantities;

  ProductList({required this.quantities});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var product = snapshot.data!.docs[index];
            return ProductItem(product: product, quantities: quantities);
          },
        );
      },
    );
  }
}

class ProductItem extends StatefulWidget {
  final QueryDocumentSnapshot<Object?> product;
  final Map<String, int> quantities;

  const ProductItem({
    required this.product,
    required this.quantities,
  });

  @override
  _ProductItemState createState() => _ProductItemState();
}

class _ProductItemState extends State<ProductItem> {
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product['name'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: widget.product.reference.collection('Variants').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var variantDoc in snapshot.data!.docs)
                  ListTile(
                    title: Row(
                      children: [
                        Text(variantDoc['name']),
                        SizedBox(width: 10),
                        Text('INR ${variantDoc['price'].toString()}'),
                        SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              if (widget.quantities
                                  .containsKey(variantDoc.id)) {
                                widget.quantities[variantDoc.id] =
                                    widget.quantities[variantDoc.id]! + 1;
                              } else {
                                widget.quantities[variantDoc.id] = 1;
                              }
                            });
                          },
                        ),
                        Text(widget.quantities.containsKey(variantDoc.id)
                            ? widget.quantities[variantDoc.id].toString()
                            : '0'),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (widget.quantities
                                      .containsKey(variantDoc.id) &&
                                  widget.quantities[variantDoc.id]! > 0) {
                                widget.quantities[variantDoc.id] =
                                    widget.quantities[variantDoc.id]! - 1;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        Divider(),
      ],
    );
  }
}

class OrderButton extends StatelessWidget {
  final Map<String, int> quantities;

  OrderButton({required this.quantities});

  Future<void> _generateAndDownloadImage(BuildContext context, List<Map<String, dynamic>> orders) async {
  final GlobalKey previewContainer = GlobalKey();

  final RenderRepaintBoundary boundary = previewContainer.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List pngBytes = byteData!.buffer.asUint8List();

  final directory = await getExternalStorageDirectory(); // Get external storage directory
  final filePath = directory!.path;
  final fileName = 'order_summary.png';
  final file = File('$filePath/$fileName');
  await file.writeAsBytes(pngBytes);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Order Summary"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(pngBytes),
            SizedBox(height: 16),
            Text("Order Placed! \n$orders"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("OK"),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            try {
              List<Map<String, dynamic>> orders = [];
              for (var variantId in quantities.keys) {
                int quantity = quantities[variantId]!;
                if (quantity > 0) {
                  // Get the parent product document of the variant
                  var productId = variantId.split('_').first;
                  var variantDoc = await FirebaseFirestore.instance
                      .collection('Products/$productId/Variants')
                      .doc(variantId)
                      .get();
                  if (variantDoc.exists) {
                    var productId = variantDoc.reference.parent!.parent!.id;
                    var productDoc = await FirebaseFirestore.instance
                        .collection('Products')
                        .doc(productId)
                        .get();
                    if (productDoc.exists) {
                      var productName = productDoc['name'];
                      var variantName = variantDoc['name'];
                      orders.add({
                        'product': productName,
                        'variant': variantName,
                        'quantity': quantity,
                      });
                    } else {
                      throw Exception(
                          'Product document with ID $productId does not exist');
                    }
                  } else {
                    throw Exception(
                        'Variant document with ID $variantId does not exist');
                  }
                }
              }

              if (orders.isNotEmpty) {
                await FirebaseFirestore.instance.collection('Orders').add({
                  'items': orders,
                });
                print('Ordered - $orders');
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Order Summary"),
                      content: Text("Order Placed! \n$orders"), // Show actual order summary here
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await _generateAndDownloadImage(context, orders);
                          },
                          child: Text("Download Image"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("OK"),
                        ),
                      ],
                    );
                  },
                );
              }
            } catch (e) {
              print('Error placing order: $e');
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Error"),
                    content: Text("Failed to place order: $e"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text("OK"),
                      ),
                    ],
                  );
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Place Final Order',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
