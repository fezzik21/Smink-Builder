#include <Arduboy2.h>
#include "src/fonts/Font3x5.h"
#include "storydata.h"

Arduboy2Base arduboy;
Font3x5 font3x5 = Font3x5();

bool g_showingTitleScreen = true;

//Story area
uint8_t g_storyNode;
uint16_t g_storyStringLength;
uint16_t g_storyStringOffset;
uint8_t g_numOptions;      
uint8_t g_options[3];
uint8_t g_optionsLengths[3];
uint16_t g_optionsOffsets[3];

uint16_t g_storyStringDisplayOffset;
uint16_t g_storyStringCurrentCharactersDisplayed;
uint8_t g_storyChoice;

uint8_t g_frameCounter;

//The first index counter of the page that corresponds to each position
uint16_t g_storyPageOffsets[20];
uint8_t g_storyPageDisplayed = 0;

void setupForStoryNode(int storyNode);
//Returns the number of characters draw if max_lines is hit, or 0 if all were drawn
int drawWrappedText(int posX, int posY, const char *str, int len, int wid, int max_lines);
const PROGMEM uint8_t title_screen[] = {
0x7f,0x3f,0x40,0xa0,0x6f,0x95,0xe3,0x8b,0x2e,0x25,0x07,0x61,0xb7,0xec,0xdc,0xe5,
0xa4,0x72,0xf1,0x2b,0xa9,0xa4,0xda,0x76,0x72,0xf8,0x70,0xb9,0x4d,0xa7,0x15,0x6d,
0x3a,0x9d,0x4e,0xa7,0xd3,0xe9,0x68,0xd3,0xd1,0xa6,0xd3,0xa1,0x29,0x1d,0x5d,0x52,
0xc9,0x4a,0xce,0x96,0x56,0x32,0x9d,0x56,0x32,0xa2,0x74,0x3a,0x1d,0x6d,0x3a,0x9d,
0x4c,0x2b,0x9d,0x4e,0x47,0x97,0x4e,0xa7,0xd3,0xe9,0x74,0x3a,0x1d,0x7c,0x84,0x3b,
0x38,0x52,0xe9,0x75,0x3a,0x39,0x59,0xed,0x2e,0x59,0x39,0x67,0x77,0x4a,0xef,0x66,
0x55,0xb6,0x92,0x95,0x73,0xae,0x96,0x95,0xac,0x5c,0xcd,0xad,0x7c,0x3a,0xa7,0x7c,
0xce,0xe9,0xb8,0x95,0x4f,0xe7,0x14,0x63,0x5b,0x59,0xc9,0x9c,0x92,0xb5,0xac,0x64,
0xe5,0x6a,0x9d,0x73,0x3a,0x9d,0x73,0x3a,0xff,0xb9,0x94,0x74,0xbb,0x89,0x72,0x4e,
0xe7,0x82,0x96,0xf0,0x06,0x1e,0x0f,0x6f,0xe0,0xf1,0xa4,0x92,0xe1,0xa9,0x92,0x60,
0xf4,0xb6,0xce,0x5d,0x32,0x58,0x09
};
// bytes:167 ratio: 0.163


void setup() {
  arduboy.boot();
  g_storyNode = 0;
  g_storyChoice = 0;
  setupForStoryNode(g_storyNode);
}

void loop() {
  // put your main code here, to run repeatedly:

  bool drewAllText = true;

  if (!(arduboy.nextFrame()))
    return;
  g_frameCounter++;
  arduboy.pollButtons();
  arduboy.clear();

  if(g_showingTitleScreen) {
    if(arduboy.justPressed(A_BUTTON)) {
      g_showingTitleScreen = false;
    }
    arduboy.drawCompressed(0, 0, title_screen);
    arduboy.display();
    return;
  }

  if(g_storyStringCurrentCharactersDisplayed == 0) {  
    if(arduboy.justPressed(A_BUTTON)) {
      if(g_numOptions > 0) {
        g_storyNode = g_options[g_storyChoice];
      } else {
        g_showingTitleScreen = true;
        g_storyNode = 0;
        setupForStoryNode(0);
        return;
      }
      g_storyChoice = 0;
      setupForStoryNode(g_storyNode);
    }
  }

  if(arduboy.justPressed(UP_BUTTON)) {
    if(g_storyChoice > 0) {
      g_storyChoice = g_storyChoice - 1;
    } else {
      if(g_storyPageDisplayed > 0) {
        g_storyPageDisplayed = g_storyPageDisplayed - 1;
      }
    }
  } 

  if(arduboy.justPressed(DOWN_BUTTON)) {
    if(g_storyPageOffsets[g_storyPageDisplayed + 1] != 0xFFFF) {
      g_storyPageDisplayed = g_storyPageDisplayed + 1;
    } else {
      if(g_storyChoice < (g_numOptions - 1)) {
        g_storyChoice = g_storyChoice + 1;
      }
    }
  }

  bool showingOptions = (g_storyPageOffsets[g_storyPageDisplayed + 1] == 0xFFFF);
  if(g_storyPageDisplayed > 0) {
    font3x5.setCursor(63, 0);
    if(g_frameCounter & 16) {
      font3x5.print('>');
    }
  }
  if(!showingOptions) {
    font3x5.setCursor(63, 56);
    if(g_frameCounter & 16) {
      font3x5.print('<');
    }
  }
  if(showingOptions) {
    uint8_t startOptions = 64 - 6 * g_numOptions;
    for(int i = 0; i < g_numOptions; i++) {
      drawWrappedText(4, startOptions + 6 * i, g_optionsOffsets[i], g_optionsLengths[i], 32, 1, true, &drewAllText);
    }
    if(g_numOptions > 0) {
      font3x5.setCursor(0, startOptions + 6 * g_storyChoice);
      font3x5.print('~');
    }
  }
  uint16_t offset = g_storyPageOffsets[g_storyPageDisplayed];
  if(showingOptions) {
    drawWrappedText(0, 6, g_storyStringOffset + offset, g_storyStringLength - offset, 32, 8 - g_numOptions, true, &drewAllText);
  } else {
    drawWrappedText(0, 6, g_storyStringOffset + offset, g_storyStringLength - offset, 32, 8, true, &drewAllText);
  }

  arduboy.display();
}

void calculateStoryPageOffsets()
{
  g_storyPageOffsets[0] = 0;
  uint16_t currentPage = 0;
  uint16_t currentCounter = 0;
  g_storyPageDisplayed = 0;

  //First, try to draw everything into a screen that has the number of options on it
  //If that works, this is the last screen
  //If that doesn't work, try to draw everything into a screen with no options on it
  //If that works, then set the next screen to the end with the options on it, and now we're done
  //If that doesn't work, set the next screen to the end with no options, and continue

  bool drewAllText = true;
  while(true) {
    uint16_t charactersDrawn = drawWrappedText(0, 6, g_storyStringOffset + currentCounter, g_storyStringLength - currentCounter, 32, 8 - g_numOptions, false, &drewAllText);
    if(drewAllText) {
      g_storyPageOffsets[currentPage + 1] = 0xFFFF;
      return;
    } else {
      uint16_t fullScreenCharactersDrawn = drawWrappedText(0, 6, g_storyStringOffset + currentCounter, g_storyStringLength - currentCounter, 32, 8, false, &drewAllText);
      if(drewAllText) {
        g_storyPageOffsets[currentPage + 1] = currentCounter + charactersDrawn;
        g_storyPageOffsets[currentPage + 2] = 0xFFFF;
        return;
      } else {
        g_storyPageOffsets[currentPage + 1] = currentCounter + fullScreenCharactersDrawn;
        currentPage = currentPage + 1;
        currentCounter = currentCounter + fullScreenCharactersDrawn;
      }
    }
  }  
}


//Every node is as follows:
//.   a byte for the length of the main story string
//.   the main story string
//.   a byte for the number of options
//.   for each option
//.        a byte for the node number of the option to point to
//.        a byte for the length of this option's string
//.        this option's string
void setupForStoryNode(int storyNode) {
  uint16_t curOffset = 0;
  g_storyStringOffset = 0;
  g_storyStringLength = 0;
  for(int i = 0; i <= storyNode; ++i) {
    g_storyStringOffset = curOffset;
    g_storyStringLength = pgm_read_byte(&storydata_bin[curOffset]);
    curOffset += 1;
    g_storyStringLength = g_storyStringLength | (pgm_read_byte(&storydata_bin[curOffset]) << 8);
    curOffset += 1;
    curOffset += g_storyStringLength;
    g_numOptions = pgm_read_byte(&storydata_bin[curOffset]);
    curOffset += 1;
    for(uint8_t i = 0; i < g_numOptions; ++i) {
      g_options[i] = pgm_read_byte(&storydata_bin[curOffset]);
      curOffset += 1;
      g_optionsLengths[i] = pgm_read_byte(&storydata_bin[curOffset]);
      curOffset += 1;
      g_optionsOffsets[i] = curOffset;
      curOffset += g_optionsLengths[i];
    }
    g_storyStringOffset += 2;
  }
  g_storyStringDisplayOffset = 0;
  calculateStoryPageOffsets();
}

int drawWrappedText(int posX, int posY, uint16_t str, uint16_t len, int wid, int max_lines, bool actuallyDrawText, bool *drewAllText) {
  int cur = 0;
  int line_count = 0;
  if(len == 0) {
    *drewAllText = true;
    return 0;
  }
  while(cur < (len - 1)) {
    if(line_count >= max_lines) {
      *drewAllText = false;
      return cur;
    }
    int oldCur = cur;
    cur += wid;
    if(cur >= len) {
      cur = len;
    } else while(cur > 0 && pgm_read_byte(&storydata_bin[str + cur]) != ' ') { 
      cur--;
    }
    font3x5.setCursor(posX, posY);
    for(int i = oldCur; i < cur; ++i) {
      if(actuallyDrawText) 
      {
        font3x5.write(pgm_read_byte(&storydata_bin[str + i]));
      }
    }
    cur++; //Remove the space
    posY += 6;
    line_count++;
  }
  *drewAllText = true;
  return 0;
}