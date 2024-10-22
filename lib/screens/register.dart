import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tickly/bloc/register/register_cubit.dart';

import '../utils/routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailEdc = TextEditingController();
  final passEdc = TextEditingController();
  bool passInvisible = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RegisterCubit, RegisterState>(
        listener: (context, state) {
          if (state is RegisterLoading) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Loading..')));
          }
          if (state is RegisterFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.msg),
                backgroundColor: Colors.red,
              ));
          }
          if (state is RegisterSuccess) {
// context.read<AuthCubit>().loggedIn();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.msg),
                backgroundColor: Colors.green,
              ));
            Navigator.pushNamedAndRemoveUntil(
                context, rLogin, (route) => false);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: ListView(
            children: [
              const SizedBox(
                height: 60,
              ),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Daftar",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff3D3F40),
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Center(
                    // Menengahkan teks kedua
                    child: Text(
                      "Silahkan daftarkan akun anda terlebih dahulu",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xff3D3F40),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(
                height: 90,
              ),
              TextFormField(
                  controller: emailEdc,
                  style:
                      const TextStyle(fontSize: 14.0, color: Color(0xff3D3F40)),
                  decoration: InputDecoration(
                      labelText: "Alamat email",
                      labelStyle: const TextStyle(
                        fontSize: 14.0,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 30.0, vertical: 15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      floatingLabelStyle: const TextStyle(fontSize: 16.0),
                      prefixIcon: const Icon(Icons.email))),
              const SizedBox(
                height: 27,
              ),
              TextFormField(
                controller: passEdc,
                style:
                    const TextStyle(fontSize: 14.0, color: Color(0xff3D3F40)),
                decoration: InputDecoration(
                  labelText: "Kata sandi",
                  labelStyle: const TextStyle(
                    fontSize: 14.0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 30.0, vertical: 15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  floatingLabelStyle: const TextStyle(fontSize: 16.0),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(passInvisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        passInvisible = !passInvisible;
                      });
                    },
                  ),
                ),
                obscureText: !passInvisible,
              ),
              const SizedBox(
                height: 50,
              ),
              ElevatedButton(
                  onPressed: () {
                    context
                        .read<RegisterCubit>()
                        .register(email: emailEdc.text, password: passEdc.text);
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(330, 50),
                      backgroundColor: const Color(0xff5780F6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: const Text(
                    "Daftar",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        color: Colors.white),
                  )),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Sudah punya akun?",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xff3D3F40)),
                  ),
                  TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text(
                        "Masuk",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff3D4DE0)),
                      ))
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
