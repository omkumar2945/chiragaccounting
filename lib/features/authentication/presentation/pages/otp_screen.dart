import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/dashboard/presentation/pages/dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String mobileNumber;

  const OtpScreen({
    super.key,
    required this.mobileNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {

  final TextEditingController otpController = TextEditingController();

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  void verifyOTP() {

    if (otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter 6 digit OTP"),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("OTP Verification"),
        centerTitle: true,
      ),

      body: Center(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(25),

          child: Container(

            width: 400,

            child: Column(

              children: [

                const Icon(
                  Icons.lock,
                  size: 90,
                  color: Colors.blue,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Verify OTP",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "OTP sent to +91 ${widget.mobileNumber}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                TextField(

                  controller: otpController,

                  keyboardType: TextInputType.number,

                  maxLength: 6,

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                  ),

                  decoration: InputDecoration(

                    hintText: "Enter OTP",

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                  ),

                ),

                const SizedBox(height: 25),

                SizedBox(

                  width: double.infinity,

                  height: 50,

                  child: ElevatedButton(

                    onPressed: verifyOTP,

                    child: const Text(
                      "Verify OTP",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),

                  ),

                ),

                const SizedBox(height: 25),

                TextButton(

                  onPressed: () {

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(

                        content: Text("OTP Sent Again"),

                      ),

                    );

                  },

                  child: const Text("Resend OTP"),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}