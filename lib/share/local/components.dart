import 'package:flutter/material.dart';


Widget buildTextForm ({
  required String label,
  void Function(String)? OnSubmit,
  TextEditingController? textController,
  IconData? preIcon,
  IconData? suffIcon,
  void Function(String)? onChanged,
  VoidCallback? Visable,
  GestureTapCallback? onTap,
  TextInputType? type,
  FormFieldValidator<String>? valid,
  bool isPassword = false,
  Color fieldColor = Colors.white,
}
    ) =>
    TextFormField(
      controller: textController,
      obscureText: isPassword,
      validator: valid ,
      keyboardType: type ,
      onFieldSubmitted: OnSubmit,
      onTap: onTap,
      onChanged: onChanged,
      // Auto-detect text direction: if user types Arabic → RTL, English → LTR
      textDirection: null,  // let Flutter auto-detect per character
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: fieldColor,
        ),
        prefixIcon: Icon(preIcon,
            color: fieldColor),
        suffixIcon: suffIcon != null
            ? IconButton(
          onPressed: Visable,
          icon: Icon(
            suffIcon,
            color: fieldColor,
          ),
        ): null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: false,
        fillColor: Colors.white70,
      ),
      style: TextStyle(
          color: fieldColor,
          fontSize: 16
      ),
    );

Widget buildLoginButton({
  double width = double.infinity,
  double height = 50,
  Color backgroundColor = const Color(0xFFe5c687),
  double radius = 10.0,
  required VoidCallback function,
  required String text,
}) => Container(
  decoration: BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(radius),
  ),
  width: width,
  height: height ,
  child: MaterialButton(
    onPressed: function,
    child: Text(text.toUpperCase(), style: TextStyle(fontSize: 20.0)),
  ),
);

void navigateTo (context,Widget) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context)=> Widget,)
);

void navigateAndReplacement (context,Widget) => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context)=> Widget),
        (route){
      return false;
    });