import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '/globals.dart' as globals;
import '/model/firestore.dart';
import '/utils/colors.dart';

class ModalBottomSheet extends StatefulWidget {
  ModalBottomSheet({super.key});

  @override
  State<ModalBottomSheet> createState() => _ModalBottomSheetState();
}

class _ModalBottomSheetState extends State<ModalBottomSheet>
    with SingleTickerProviderStateMixin {
  late Timer timer;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool isLoading = true;

  int namesIndex = 0;
  List<String> names = [
    "family",
    "friends",
    "best friend",
    "siblings",
    "so",
  ];

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (namesIndex < 4) {
        setState(() {
          namesIndex++;
          _animationController.reset();
          _animationController.forward();
        });
      } else {
        setState(() {
          namesIndex = 0;
          _animationController.reset();
          _animationController.forward();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50), topRight: Radius.circular(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Container(
              width: 50,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "0 out of 20 friends",
              style: GoogleFonts.rubik(
                  fontSize: 26, fontWeight: FontWeight.w700, color: white),
            ),
          ),
          SizedBox(
              height: 25,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Add your  ",
                        style: GoogleFonts.rubik(
                            fontSize: 18,
                            color: termsText,
                            fontWeight: FontWeight.w600)),
                    FadeTransition(
                      opacity: _animation,
                      child: Text("${names[namesIndex]}  ",
                          style: GoogleFonts.rubik(
                              fontSize: 18,
                              color: primaryColor,
                              fontWeight: FontWeight.w600)),
                    ),
                    namesIndex == 0
                        ? FadeTransition(
                            opacity: _animation,
                            child: Text("👨‍👩‍👧‍👦",
                                style: GoogleFonts.rubik(fontSize: 18)),
                          )
                        : (namesIndex == 3
                            ? FadeTransition(
                                opacity: _animation,
                                child: Text("👧🏾👦🏻",
                                    style: GoogleFonts.rubik(fontSize: 18)),
                              )
                            : (namesIndex == 4
                                ? FadeTransition(
                                    opacity: _animation,
                                    child: Text("❤️",
                                        style: GoogleFonts.rubik(fontSize: 18)),
                                  )
                                : Container()))
                  ])),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Row(
              children: [
                const Icon(Iconsax.people, color: Colors.white70),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Your friends",
                      style: GoogleFonts.rubik(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
          globals.sentRequestList.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white70),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("Sent requests",
                            style: GoogleFonts.rubik(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      )
                    ],
                  ),
                )
              : Container(),
          globals.sentRequestList.isNotEmpty
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: globals.sentRequestList.length,
                  itemBuilder: (context, int index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: friendsListItems(
                          "",
                          "${globals.sentRequestList[index]['name'].split(" ")[0][0]}${globals.sentRequestList[index]['name'].split(" ")[1][0] ?? ""}",
                          globals.sentRequestList[index]['name'],
                          globals.sentRequestList[index]['number'], () async {
                        await firestore
                            .collection('friendRequests')
                            .doc(
                                '${userStorage.read('phoneNumber')}-${globals.sentRequestList[index]['number']}')
                            .delete();
                        globals.commonContactsList.add({
                          'name': globals.sentRequestList[index]['name'],
                          'number': globals.sentRequestList[index]['number'],
                        });
                        globals.sentRequestList.removeAt(index);
                      }, false),
                    );
                  },
                )
              : Container(),
          globals.commonContactsList.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.sparkles,
                          color: Colors.white70),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("Suggestions",
                            style: GoogleFonts.rubik(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      )
                    ],
                  ),
                )
              : Container(),
          globals.commonContactsList.isNotEmpty
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: globals.commonContactsList.length,
                  itemBuilder: (context, int index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: friendsListItems(
                          "",
                          "${globals.commonContactsList[index]['name'].split(" ")[0][0]}${globals.commonContactsList[index]['name'].split(" ")[1][0] ?? ""}",
                          globals.commonContactsList[index]['name'],
                          globals.commonContactsList[index]['number'], () {
                        setState(() {
                          isLoading = false;
                        });
                        Future.delayed(
                          const Duration(seconds: 2),
                        ).then((value) async {
                          setState(() {
                            isLoading = true;
                          });

                          await firestore
                              .collection('friendRequests')
                              .doc(userStorage.read('uid'))
                              .set({
                            'sender_id': userStorage.read('uid'),
                            'receiver_id': await firestore
                                .collection('users')
                                .where('phoneNumber',
                                    isEqualTo: globals.commonContactsList[index]
                                        ['number'])
                                .get()
                                .then((snapshot) {
                              var data = snapshot.docs.first.id;
                              return data;
                            }),
                            'status': 'pending',
                          });

                          globals.sentRequestList.add({
                            'name': globals.commonContactsList[index]['name'],
                            'number': globals.commonContactsList[index]
                                ['number'],
                          });
                          globals.commonContactsList.removeAt(index);
                        });
                      }, true),
                    );
                  },
                )
              : Container(),
        ]),
      ),
    );
  }

  Widget friendsListItems(String pfpLink, String pfpAlt, String name,
      String phoneNumber, void Function() onClick, bool isSuggestion) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 33,
            backgroundColor: secondaryColor,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          pfpLink.isNotEmpty
              ? CircleAvatar(
                  radius: 25,
                  backgroundColor: secondaryColor,
                  backgroundImage: NetworkImage(pfpLink),
                )
              : CircleAvatar(
                  radius: 25,
                  backgroundColor: secondaryColor,
                  child: Text(pfpAlt,
                      style: GoogleFonts.rubik(
                          fontSize: 20,
                          color: termsText,
                          fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: SizedBox(
          height: 50,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  name,
                  style: GoogleFonts.rubik(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
              phoneNumber.isNotEmpty
                  ? Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        phoneNumber,
                        style: GoogleFonts.rubik(
                            fontSize: 14,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500),
                      ),
                    )
                  : Container()
            ],
          ),
        ),
      ),
      Expanded(
        child: Align(
            alignment: Alignment.centerRight,
            child: isSuggestion
                ? TextButton(
                    onPressed: onClick,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                    child: !isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: black,
                              strokeWidth: 2,
                            ))
                        : SizedBox(
                            height: 20,
                            child: Text(
                              "+ Add",
                              style: GoogleFonts.rubik(
                                  color: black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18),
                            ),
                          ),
                  )
                : GestureDetector(
                    onTap: onClick,
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: secondaryColor,
                      child: Icon(Icons.close, color: white, size: 20),
                    ),
                  )),
      ),
    ]);
  }
}
