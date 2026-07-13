import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController mobileController = TextEditingController();

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  void sendOTP() {
    String mobile = mobileController.text.trim();

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid 10 digit mobile number"),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          mobileNumber: mobile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text("Chirag Accounting"),
        centerTitle: true,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),

          child: SizedBox(
            width: 400,

            child: Column(
              children: [

                const Icon(
                  Icons.account_balance,
                  size: 90,
                  color: Colors.blue,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Welcome",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Smart Accounting Solution",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,

                  decoration: InputDecoration(
                    labelText: "Mobile Number",
                    prefixText: "+91 ",
                    prefixIcon: const Icon(Icons.phone),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,

                  child: ElevatedButton(
                    onPressed: sendOTP,

                    child: const Text(
                      "Send OTP",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Powered by Chirag Associates",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}