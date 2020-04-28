unit SAME;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Menus, IniFiles, ComCtrls;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    mniGame: TMenuItem;
    mniNew: TMenuItem;
    mniN3: TMenuItem; //Separator
    mniExit: TMenuItem;
    mniHighscores: TMenuItem;
    mniSettings: TMenuItem;
    ImageOn1: TImage;
    ImageOn2: TImage;
    ImageOn3: TImage;
    ImageOn4: TImage;
    ImageOff1: TImage;
    ImageOff2: TImage;
    ImageOff3: TImage;
    ImageOff4: TImage;
    ImageBlank: TImage;
    mniScore: TMenuItem;
    mniHint: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure DrawBall(X, Y, ColourIndex: Integer);
    procedure DrawBallSel(X, Y, ColourIndex: Integer);
    procedure FlagAdjacent(X, Y: Integer; Colour: Byte);
    procedure TestClick(X, Y: Integer);
    procedure ScoreClick;
    procedure NewGame;
    procedure EndGame;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mniNewClick(Sender: TObject);
    procedure mniExitClick(Sender: TObject);
    procedure mniHighscoresClick(Sender: TObject);
    procedure mniSettingsClick(Sender: TObject);
    procedure mniHintClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  private
    { Private declarations }
  public
    { Public declarations }
    //Settings
    BoardSizeX, BoardSizeY, NumColours: Integer;
    //High scores
    HSname: array[1..10] of string;
    HSscore: array[1..10] of DWORD;
    procedure Paint; override; //Paint override needed to display new game from FormCreate
  end;

const
  BallSize = 32; //Size of a block in pixels

var
  Form1: TForm1;
  Ball: array[0..4] of^TBitmap;
  BallSel: array[0..4] of^TBitmap;
  Board: array[0..51, 0..31] of Byte; //Max size is 50x30
  TestBoard: array[0..51, 0..31] of Boolean;
  HintX, HintY: Byte;
  //Scoring
  Score, ClickScore: DWord;

implementation

{$R *.dfm}

uses
  OPTIONS, HIGHSCORES;

procedure TForm1.FlagAdjacent(X, Y: Integer; Colour: Byte); //Recursive
begin
  //TestBoard = false makes sure ball not already checked, otherwise: infinite loop
  //Test left
  if (Board[X - 1, Y] = Colour) and (TestBoard[X - 1, Y] = False) then
  begin
    TestBoard[X - 1, Y] := True;
    FlagAdjacent(X - 1, Y, Colour);
  end;
   //Test right
  if (Board[X + 1, Y] = Colour) and (TestBoard[X + 1, Y] = False) then
  begin
    TestBoard[X + 1, Y] := True;
    FlagAdjacent(X + 1, Y, Colour);
  end;
  //Test up
  if (Board[X, Y - 1] = Colour) and (TestBoard[X, Y - 1] = False) then
  begin
    TestBoard[X, Y - 1] := True;
    FlagAdjacent(X, Y - 1, Colour);
  end;
  //Test down
  if (Board[X, Y + 1] = Colour) and (TestBoard[X, Y + 1] = False) then
  begin
    FlagAdjacent(X, Y + 1, Colour);
    TestBoard[X, Y + 1] := True;
  end;
end;

procedure TForm1.TestClick(X, Y: Integer);
var
  LX, LY: Integer;
begin
  //Initialise test matrix
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      TestBoard[LX, LY] := False;
  //Recursivelty look for neighbours of the clicked ball colour
  FlagAdjacent(X, Y, Board[X, Y]);
  //Count balls in cluster
  ClickScore := 0;
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      if (TestBoard[LX, LY] = True) then
        Inc(ClickScore);
  //If less than 2 balls: not a valid group, exit
  if (ClickScore < 2) then
    Exit; //Yes: exit
  //Reuse ClickScore to store actual score of the click, use (n-1)^2
  ClickScore := (ClickScore - 1) * (ClickScore - 1);
  //Redraw all board
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      if (TestBoard[LX, LY] = True) then
        DrawBallSel(LX, LY, Board[LX, LY]) //Clicked cluster
      else
        DrawBall(LX, LY, Board[LX, LY]); //In case this was highlighted from a previous click
end;

procedure TForm1.ScoreClick;
var
  LX, LY, i, j: Integer;
  TempVector: array[1..30] of Byte;
begin
  //Remove all balls from clicked cluster
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      if (TestBoard[LX, LY] = True) then
        Board[LX, LY] := 0;
  //Drop balls vertically where balls removed
  j := 0;
  //Process columns left to right
  for LX := 1 to BoardSizeX do
  begin
    //Initialise temp column
    for LY := 1 to BoardSizeY do
      TempVector[LY] := 0;
    //Populate temp column with only non-zero values
    i := BoardSizeY + 1;
    for LY := BoardSizeY downto 1 do
      if (Board[LX, LY] > 0) then
      begin
        Dec(i);
        TempVector[i] := Board[LX, LY];
      end;
    //Any non zero values?
    if (i < BoardSizeY + 1) then
    begin
      //Yes: we have a new column to add
      Inc(j);
      //Copy whole temp column into destination
      for LY := 1 to BoardSizeY do
        Board[j, LY] := TempVector[LY];
    end;
  end;
    //At this point we might have some columns leftover, we need to make sure they are empty
  if (j < BoardSizeX) then
    for LX := j + 1 to BoardSizeX do
      for LY := 1 to BoardSizeY do
        Board[LX, LY] := 0;
  //Redraw board
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      DrawBall(LX, LY, Board[LX, LY]);
  //Update score
  Inc(Score, ClickScore);
  //Initialise test matrix so that click event not misled that we already clicked a group
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      TestBoard[LX, LY] := False;
  //Test game end
  for LX := 1 to BoardSizeX do
    for LY := 1 to BoardSizeY do
      if (Board[LX, LY] > 0) then
        if (Board[LX, LY] = Board[LX + 1, LY]) or (Board[LX, LY] = Board[LX, LY + 1]) then
        begin
          HintX := LX;
          HintY := LY;
          Exit; //One move found: no need to carry on
        end;
  //Reached here=no more moves. Check if high score
  if (Board[1, BoardSizeY] = 0) then
    Inc(Score, 1000); //1000 points bonus for clearing board
  EndGame;
end;

procedure TForm1.DrawBall(X, Y, ColourIndex: Integer);
begin
  Form1.Canvas.Draw((X - 1) * BallSize, (Y - 1) * BallSize, Ball[ColourIndex]^);
end;

procedure TForm1.DrawBallSel(X, Y, ColourIndex: Integer);
begin
  Form1.Canvas.Draw((X - 1) * BallSize, (Y - 1) * BallSize, BallSel[ColourIndex]^);
end;

procedure TForm1.NewGame;
var
  X, Y: Byte;
begin
  Score := 0;
  mniScore.Caption := 'Score = 0';
  //Clear boards logically
  for X := 0 to 51 do //Checking neighbours of balls on the border will work but always false
    for Y := 0 to 31 do
    begin
      Board[X, Y] := 0;
      TestBoard[X, Y] := False;
    end;
  //Set board
  Form1.ClientWidth := BoardSizeX * 32;
  Form1.ClientHeight := BoardSizeY * 32;
  Form1.Canvas.FillRect(Rect(0, 0, ClientWidth, ClientHeight));
  Randomize;
  for X := 1 to BoardSizeX do
    for Y := 1 to BoardSizeY do
    begin
      Board[X, Y] := Random(NumColours) + 1;
      DrawBall(X, Y, Board[X, Y]);
    end;
  //Set hint
  for X := 1 to BoardSizeX do
    for Y := 1 to BoardSizeY do
      if (Board[X, Y] > 0) then
        if (Board[X, Y] = Board[X + 1, Y]) or (Board[X, Y] = Board[X, Y + 1]) then
        begin
          HintX := X;
          HintY := Y;
          Exit; //Not that we Exit the procedure altogether! If need to do something later, replace with a break
        end;
end;

procedure TForm1.EndGame;
var
  X, Y: Byte;
  myINI: TINIFile;
  //High score
  WinnerName: string;
begin
  //Highscore?
  for X := 1 to 10 do
  begin
    if (Score > HSscore[X]) then
    begin
      //Get name
      WinnerName := InputBox('You''re Winner!', 'You placed #' + IntToStr(X) + ' with your score of ' + IntToStr(Score) + '.' + slinebreak + 'Enter your name:', HSname[1]);
      //Shift high scores downwards; If placed 10, skip as we'll simply overwrite last score
      if X < 10 then
        for Y := 10 downto X + 1 do
        begin
          HSname[Y] := HSname[Y - 1];
          HSscore[Y] := HSscore[Y - 1];
        end;
      //Set new high score
      HSname[X] := WinnerName;
      HSscore[X] := Score;
      //Save high scores to INI file
      myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'SliSame.ini');
      for Y := 1 to 10 do
      begin
        myINI.WriteString('HighScores', 'Name' + IntToStr(Y), HSname[Y]);
        myINI.WriteInteger('HighScores', 'Score' + IntToStr(Y), HSscore[Y]);
      end;
      //Close INI file
      myINI.Free;
      //Exit so that we only get 1 high score!
      Exit;
    end;
  end;
  ShowMessage('No more moves and your score of ' + IntToStr(Score) + ' is not a high score.');
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  myINI: TINIFile;
  i: Byte;
begin
  //Initialise options from INI file
  myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'SliSame.ini');
  BoardSizeX := myINI.ReadInteger('Settings', 'BoardSizeX', 15);
  BoardSizeY := myINI.ReadInteger('Settings', 'BoardSizeY', 10);
  NumColours := myINI.ReadInteger('Settings', 'NumColours', 3);
  //Read high scores from INI file
  for i := 1 to 10 do
  begin
    HSname[i] := myINI.ReadString('HighScores', 'Name' + IntToStr(i), 'Nobody');
    HSscore[i] := myINI.ReadInteger('HighScores', 'Score' + IntToStr(i), (11 - i) * 100);
  end;
  myINI.Free;
  //Initialise shapes images
  New(Ball[0]);
  Ball[0]^ := ImageBlank.Picture.Bitmap;
  New(Ball[1]);
  Ball[1]^ := ImageOn1.Picture.Bitmap;
  New(Ball[2]);
  Ball[2]^ := ImageOn2.Picture.Bitmap;
  New(Ball[3]);
  Ball[3]^ := ImageOn3.Picture.Bitmap;
  New(Ball[4]);
  Ball[4]^ := ImageOn4.Picture.Bitmap;
  New(BallSel[0]);
  BallSel[0]^ := ImageBlank.Picture.Bitmap;
  New(BallSel[1]);
  BallSel[1]^ := ImageOff1.Picture.Bitmap;
  New(BallSel[2]);
  BallSel[2]^ := ImageOff2.Picture.Bitmap;
  New(BallSel[3]);
  BallSel[3]^ := ImageOff3.Picture.Bitmap;
  New(BallSel[4]);
  BallSel[4]^ := ImageOff4.Picture.Bitmap;
  //Launch a new game
  NewGame;
end;

procedure TForm1.Paint;
//Paint override needed, otherwise won't display game if started from FormCreate
begin
  NewGame;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.Terminate;
end;

procedure TForm1.mniNewClick(Sender: TObject);
begin
  NewGame;
end;

procedure TForm1.mniHintClick(Sender: TObject);
begin
  //No need to test for game end: HintX and HintY will have previous values and TestClick will return without doing anything
  TestClick(HintX, HintY);
end;

procedure TForm1.mniExitClick(Sender: TObject);
begin
  Close;
end;

procedure TForm1.mniHighscoresClick(Sender: TObject);
begin
  if Form3.Visible = False then
    Form3.Show
  else
    Form3.Hide;
end;

procedure TForm1.mniSettingsClick(Sender: TObject);
begin
  if Form2.Visible = False then
    Form2.Show
  else
    Form2.Hide;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  BallX, BallY: Integer;
begin
  BallX := X div BallSize + 1;
  BallY := Y div BallSize + 1;
  //Empty space? Exit
  if (Board[BallX, BallY] = 0) then
    Exit;
  //Is it flagged?
  if (TestBoard[BallX, BallY] = False) then
  begin
    //No: preview click
    TestClick(BallX, BallY);
    if (ClickScore > 0) then
      mniScore.Caption := 'Click score = ' + IntToStr(ClickScore);
  end
  else
  begin
    //Yes: we clicked after test, process click
    ScoreClick;
    mniScore.Caption := 'Score = ' + IntToStr(Score);
  end;
end;

end.

