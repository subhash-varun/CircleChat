import 'package:flutter/material.dart';

class GlobalWidget {
  PreferredSizeWidget globalAppBar(
    BuildContext context,
    String title, {
    bool cart = false,
    bool wishlist = false,
    Color? backgroundColor,
  }) {
    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      actions: [
        if (wishlist)
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.favorite_border),
          ),
        if (cart)
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.shopping_cart_outlined),
          ),
      ],
    );
  }
}
