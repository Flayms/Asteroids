#!perl
use strict;
use warnings;

package MainLogic; {
  use File::Spec;
  use FindBin qw( $Bin );

  use constant {
    FALSE                   => 0,
    TRUE                    => 1,
    LEVEL_COMPLETION_POINTS => 1000,
    _UPDATE_SPEED_MS        => 20,
    SCOREBOARD_SCORE_AMOUNT => 10
  };

  my $fieldSize = Size->new(900, 900);
  my $playerSize = Size->new(25, 35);

  #asteroid amounts perl level
  my @asteroidAmounts = (
    2,     3,     5,     7,    11,    13,    17,    19,    23,    29,    31,    37,    41,    43,
    47,    53,    59,    61,    67,    71,    73,    79,    83,    89,    97,   101,   103,   107,
    109,   113,   127,   131,   137,   139,   149,   151,   157,   163,   167,   173,   179,   181,
    191,   193,   197,   199,   211,   223,   227,   229,   233,   239,   241,   251,   257,   263,
    269,   271,   277,   281,   283,   293,   307,   311,   313,   317,   331,   337,   347,   349,
    353,   359,   367,   373,   379,   383,   389,   397,   401,   409,   419,   421,   431,   433,
    439,   443,   449,   457,   461,   463,   467,   479,   487,   491,   499,   503,   509,   521,
    523,   541);

  my %keys = (
    Move   => 'w',
    Shoot  => 'q',
    Shoot2 => 'space'
  );

  my $levelIndex = 1;
  my $isGamerOver = FALSE;
  my $scoreBoardPath = File::Spec->catfile($Bin,'scoreboard.txt');
  my $player;
  my $playerNameEntered = FALSE;
  my $score = 0;
  my @bullets;
  my @asteroids;

  #tk elements
  my $mw = Tk::MainWindow->new();

  Main();

  sub Main {
    ImageManipulation::SetMw($mw);
    UI::Initialize($mw, $fieldSize);
    GameElement::Asteroid::Initialize();


    #CreateMenu();
    StartGame();
    $mw->MainLoop();
  }

  sub CreateMenu(){
    $mw->Button(
      -text    => "Start Game!",
      -command => \&StartGame

    )->pack();
  }

  sub StartGame() {


    UI::CreateBackground();
    $player = GameElement::Player->new(
      Point->new($fieldSize->{Width} / 2, $fieldSize->{Height} / 2),
      $playerSize, __PACKAGE__, $fieldSize, $mw
    );
    UI::CreateScore($levelIndex, $score);
    CreateAsteroids();
    SetupWindow();
  }

  sub GetMW {
    return $mw;
  }

  sub GetScoreBoardPath {
    return $scoreBoardPath;
  }

  #creates the asteroids for the level and their canvas elements
  sub CreateAsteroids {
    my $amount = $asteroidAmounts[$levelIndex - 1];
    for (my $i = 0; $i < $amount; ++$i) {
      my $asteroid = GameElement::Asteroid->new($fieldSize, __PACKAGE__);

      $asteroids[$i] = $asteroid;
    }
  }

  # sets up the tk window
  sub SetupWindow {
    $mw->title("Spaceship");
    $mw->bind('<Any-KeyPress>', \&KeyPressed);
    $mw->bind('<Any-KeyRelease>', \&KeyReleased);
    $mw->repeat(_UPDATE_SPEED_MS, \&Update);
  }

  #updates the game and draws it
  sub Update {
    if ($isGamerOver) {
      if ($playerNameEntered) {
        return;
      }

      my $playerName = UI::GetPlayerName();

      #no empty strings or spaces allowed
      if (!(defined $playerName) || $playerName =~ /\s/) {
        return;
      }

      print "playerName: $playerName \n";

      $playerNameEntered = TRUE;
      ShowScoreBoard();
      return;
    }

    $player->Update(UI::GetCursorPosition());
    UpdateBullets();
    UpdateAsteroids();

    HandleAsteroidBulletCollision();
    HandleLevelCompletion();

    Draw();
  }

  sub CreateScoreboardText {
    my @lines = Utils::ReadAllLines($scoreBoardPath);
    my $text;
    my $scoreAdded = FALSE;
    my $count = SCOREBOARD_SCORE_AMOUNT;
    my $playerName = UI::GetPlayerName();

    for (my $i = 0; $i < $count; ++$i) {
      my $line = $lines[$i];
      my @pair = split(" ", $line);

      unless ($scoreAdded) {
        #add player score
        if ($score > $pair[1]) {
          $text = $text . $playerName . " $score\n";
          $count--;
          $scoreAdded = TRUE;
        }
      }

      $text = $text . "$line";
    }

    Utils::WriteText($scoreBoardPath, $text);
  }


  #updates bullets and deletes them when out of field
  # TODO: method makes things from different abstraction layers UI and BL
  sub UpdateBullets {
    #updates
    for (my $i = scalar @bullets - 1; $i >= 0; --$i) {
      my $bullet = $bullets[$i];
      $bullet->Update();

      #deletes out of field bullets
      if ($bullet->{Position}->{X} > $fieldSize->{Width} or $bullet->{Position}->{Y} > $fieldSize->{Height}) {
        UI::DeleteElement($bullet->{Id});
        splice(@bullets, $i, 1);
      }
    }
  }

  #updates asteroids and sets gameOver when collision with player
  # TODO: method makes things from different abstraction layers UI and BL
  sub UpdateAsteroids {
    foreach my $asteroid (@asteroids) {
      $asteroid->Update();

      if ($player->IntersectsWith($asteroid)) {
        UI::DisplayEntry();
        $isGamerOver = TRUE;
        return;
      }
    }
  }

  sub ShowScoreBoard {
    CreateScoreboardText();
    UI::CreateLoosingScreen();
  }

  #handles collision for each asteroid and bullet
  # TODO: method makes things from different abstraction layers UI and BL
  sub HandleAsteroidBulletCollision {

    for (my $i = scalar @asteroids - 1; $i >= 0; --$i) {
      my $asteroid = $asteroids[$i];

      for (my $j = scalar @bullets- 1; $j >= 0; --$j) {
        my $bullet = $bullets[$j];

        if ($asteroid->Contains($bullet->{Position})) {

          UI::DeleteElement($bullet->{Id});
          splice(@bullets, $j, 1);

          $score += $asteroid->{Size}->{Width};
          SplitAsteroid($asteroid, $i, $bullet->{Direction});
        }
      }
    }
  }

  #splits and/or deletes asteroid
  # TODO: method makes things from different abstraction layers UI and BL
  sub SplitAsteroid {
    my ($asteroid, $i, $bulletDirection) = @_;

    if ($asteroid->{CanSplit}) {

      my $newAsteroid =  $asteroid->Split($bulletDirection);
      push (@asteroids, $newAsteroid);
    } else {

      UI::DeleteElement($asteroid->{Id});
      splice(@asteroids, $i, 1);
    }
  }

  #updates the score and creates new asteroids when level completed
  sub HandleLevelCompletion {
    my $count = scalar @asteroids;

    if ($count == 0) {
      $score += LEVEL_COMPLETION_POINTS;
      ++$levelIndex;
      CreateAsteroids();
    }
  }

  #draws all the elements of the canvas
  sub Draw() {
    my $count = scalar @asteroids;

    for (my $i = 0; $i < $count; ++$i) {
      UI::DrawCanvasElement($asteroids[$i]);
    }

    UI::DeleteScore();
    UI::CreateScore($levelIndex, $score);
    UI::DrawCanvasElement($player);
    UI::DrawBullets(@bullets);
  }

  #handles key press
  sub KeyPressed {
    my $key = $_[0]->XEvent->K;

    if ($key eq $keys{Move}) {
      $player->StartMoving();

    } elsif ($key eq $keys{Shoot} || $key eq $keys{Shoot2}) {
      $player->StartShooting();
    }
  }

  #handles key release
  sub KeyReleased {
    my $key = $_[0]->XEvent->K;

    if ($key eq $keys{Move}) {
      $player->StopMoving();

    } elsif ($key eq $keys{Shoot} || $key eq $keys{Shoot2}) {
      $player->StopShooting();
    }
  }

  #adds bullet to array
  sub AddBullet {
    my ($this, $bullet) = @_;
    push(@bullets, $bullet);
  }

}

package UI; {
  use File::Spec;
  use FindBin qw( $Bin );

  my $mw;
  my $canvas;
  my $scoreId;
  my $playerName = "";

  sub Initialize {
    my ($window, $fieldSize) = @_;
    $mw = $window;
    $canvas = $mw->Canvas(-width => $fieldSize->{Width}, -height => $fieldSize->{Height})->pack();
  }

  sub CreateBackground {
    my $image = $mw->Photo(-file => File::Spec->catfile($Bin, 'stars.png'));
    $canvas->createImage(0, 0, -image=>$image, anchor => 'nw');
  }

  sub DeleteElement {
    my ($id) = @_;
    $canvas->delete($id);
  }

  sub DeleteScore {
    $canvas->delete($scoreId);
  }

  #creates the score text
  sub CreateScore {
    my ($levelIndex, $score) = @_;
    $scoreId = $canvas->createText(60, 20, -text => "Level: $levelIndex | Score: $score", -fill => "white");
  }

  #creates a gameElement on the canvas
  sub CreateCanvasElement {
    my ($image, $position) = @_;
    return $canvas->createImage($position->{X}, $position->{Y}, -image=> $image);
  }

  sub ExchangeCanvasElement {
    my ($id, $image, $position) = @_;
    DeleteElement($id);
    return CreateCanvasElement($image, $position);
  }

  #draws a gameElement on the canvas
  sub DrawCanvasElement {
    my ($element) = @_;
    my $position = $element->{Position};
    my $size = $element->{Size};
    $canvas->coords($element->{Id}, $position->{X} + $size->{Width} / 2,
      $position->{Y} + $size->{Height} / 2);
  }

  #draws all bullets on the canvas
  sub DrawBullets {
    my (@bullets) = @_;
    my $count = scalar @bullets;

    for (my $i=0; $i < $count; ++$i) {
      my $bullet = $bullets[$i];
      my $x = $bullet->{Position}->{X};
      my $y = $bullet->{Position}->{Y};

      $canvas->coords($bullet->{Id}, $x, $y, $x + 10, $y + 10);
    }
  }

  sub DisplayEntry {
    my $entry = $mw->Entry()->pack();
    my $button = $mw->Button(
      -text => 'enter',
      -command => sub{
        my $entryValue = $entry->get();
        if ($entryValue eq "") { return }
        $playerName = $entryValue;
      },
    )->pack();
  }

  sub GetPlayerName {
    return $playerName;
  }

  sub CreateLoosingScreen {
    my $filePath = MainLogic::GetScoreBoardPath();
    my $caption = "----ScoreBoard----\n";
    my $text = Utils::ReadText($filePath);
    $text = $caption . $text;

    $canvas->createText(400, 450, -text => $text, -font =>'big', -fill => "white");
  }

  sub CreateBullet {
      my ($position) = @_;
      my $x = $position->{X};
      my $y = $position->{Y};

      return $canvas->createOval($x, $y, $x + 10, $y + 10, -fill => 'red');
  }

  #gets the current cursor position relative to the canvas
  sub GetCursorPosition {
    return Point->new($canvas->pointerx - $canvas->rootx, $canvas->pointery - $canvas->rooty);
  }

}

package Point; {

  #creates a new point
  sub new {
    my ($class, $x, $y) = @_;
    return bless {
      X => $x,
      Y => $y
    }, ref($class)||$class||__PACKAGE__;
  }

  # creates a point with the coords (0, 0)
  sub Empty {
    return __PACKAGE__->new(0,0);
  }

  sub X($;$){
    my($this,$value)=@_;

    $this->{X}=$value if scalar(@_>1);
    return $this->{X};
  }

  sub Y($){my($this)=@_;return $this->{Y};}

  #adds the values of a point onto this one
  sub Add {
    my ($this, $point) = @_;
    return(Point->new($this->{X} + $point->{X}, $this->{Y} + $point->{Y}))
  }

  # substract the values of a point from this one
  sub Substract {
    my ($this, $point) = @_;
    return(Point->new($this->{X} - $point->{X}, $this->{Y} - $point->{Y}))
  }

  # multiply the point with a value
  sub Multiply {
    my ($this, $value) = @_;
    return(Point->new($this->{X} * $value, $this->{Y} * $value))
  }

  #divides the point with a value
  sub Divide {
    my ($this, $value) = @_;
    return(Point->new($this->{X} / $value, $this->{Y} / $value))
  }

};

package Size; {

  #creates a new size
  sub new {
    my ($class, $width, $height) = @_;
    return bless {
      Width => $width,
      Height => $height
    }, ref($class)||$class||__PACKAGE__;
  }
};

package Rectangle; {
  #creates a new Rectangle
  sub new {
    my ($class, $location, $size) = @_;
    return bless {
      Location => $location,
      Size => $size
    }, ref($class)||$class||__PACKAGE__;
  }
}

package GameElement; {
  use constant {
    FALSE => 0,
    TRUE  => 1
  };

  #needs position field
  #needs size field
  #needs direction field
  #needs speed field

  #moves this by its direction and speed
  sub Move {
    my ($this) = @_;

    my $amount = $this->{Direction}->Multiply($this->{Speed});
    my $posX = $this->{Position}->{X};
    my $posY = $this->{Position}->{Y};

    $this->{Position} = $this->{Position}->Add($amount);
  }

  #moves this and keeps it in field
  sub MoveModulo {
    my ($this) = @_;
    Move($this);
    my $position = $this->{Position};
    my $size = $this->{Size};
    my $cX = $position->{X} + ($size->{Width} / 2);
    my $cY = $position->{Y} + ($size->{Height} / 2);
    my $fieldSize = $this->{FieldSize};
    my $fWidth = $fieldSize->{Width};
    my $fHeight = $fieldSize->{Height};

    if ($cX < 0) {
      $position->{X} += $fWidth;
    } elsif ($cX > $fWidth) {
      $position->{X} -= $fWidth;
    }

    if ($cY < 0) {
      $position->{Y} += $fHeight;
    } elsif ($cY > $fHeight) {
      $position->{Y} -= $fHeight;
    }
  }

  #checks if of this contain a specific point
  sub Contains {
    my ($this, $point)   = @_;
    my $Pos = $this->{Position};
    my $x = $Pos->{X};
    my $y = $Pos->{Y};
    my $pX = $point->{X};
    my $pY = $point->{Y};
    my $size = $this->{Size};

    if ($pX >= $x and
      $pX <= $x + $size->{Width} and
      $pY >= $y and
      $pY <= $y + $size->{Height}) {
      return TRUE;
    }
    return FALSE;
  }

  #checks if this intersects with another gameElement
  sub IntersectsWith {
    my ($this, $otherObj) = @_;
    my $l1 = $this->{Position};
    my $r1 = Point->new($l1->{X} + $this->{Size}->{Width}, $l1->{Y} + $this->{Size}->{Height});
    my $l2 = $otherObj->{Position};
    my $r2 = Point->new($l2->{X} + $otherObj->{Size}->{Width}, $l2->{Y} + $otherObj->{Size}->{Height});

    #If one rectangle is on left side of other
    if ($l1->{X} >= $r2->{X} or $l2->{X} >= $r1->{X}) {
      return FALSE;
    }

    #If one rectangle is above other
    if ($l1->{Y} >= $r2->{Y} or $l2->{Y} >= $r1->{Y}) {
      return FALSE;
    }

    return TRUE;
  }
}

package GameElement::Player; {
  use parent -norequire, 'GameElement';
  use FindBin qw( $Bin );

  use constant {
    FALSE           => 0,
    TRUE            => 1,

    _IMAGE_NAME => "spaceship.png",
    _MIN_SPEED      => 1.5,
    _MAX_SPEED      => 8,
    _ACCELERATION   => 0.6,
    _RESISTANCE     => 0.1,
    _SHOT_COOLDOWN   => 6,
    _MOVE_STOP_TIME => 3
  };

  #creates a new player
  sub new {
    my ($class, $position, $size, $mainLogic, $fieldSize) = @_;
    my $image = ImageManipulation::CreateImage(File::Spec->catfile($Bin,_IMAGE_NAME), $size->{Width}, $size->{Height});
    my $id = UI::CreateCanvasElement($image, $position);

    return bless {
      Position         => $position,
      Size             => $size,
      _logic           => $mainLogic,
      FieldSize        => $fieldSize,
      Direction        => Point->Empty(), #the direction in which the ship is flying
      DirectionLooking => Point->Empty(), #the direction in which the ship is looking
      IsMoving         => FALSE,
      Speed            => 0,
      MoveStopTime     => 0,
      IsShooting       => FALSE,
      ShootCounter     => 7, #should be done with timer
      Id               => $id,
      Image            => $image
    }, ref($class)||$class||__PACKAGE__;
  }

  #sets the moving flag true
  sub StartMoving {
    my ($this) = @_;
    $this->{IsMoving} = TRUE;
  }

  #sets the moving flag false
  sub StopMoving {
    my ($this) = @_;
    $this->{IsMoving} = FALSE;
    $this->{MoveStopTime} = _MOVE_STOP_TIME;
  }

  #updates the players direction, position and shots
  sub Update {
    my ($this, $cursorPos) = @_;

    $this->_ChangeDirection($cursorPos);
    $this->Move();
    $this->_Shoot();
  }

  #moves the player
  sub Move {
    my ($this) = @_;
    my $speed = $this->{Speed};

    #accelerate player if not at max speed
     if ($this->{IsMoving}) {

      if ($speed <= _MAX_SPEED) {
        if ($speed < _MIN_SPEED) {
          $speed = _MIN_SPEED
        } else {
          $speed += _ACCELERATION;
        }

        if ($speed > _MAX_SPEED) {
          $speed = _MAX_SPEED;
        }

        $this->{Speed} = $speed;
      }
    }

    #slow player down if not at min speed
    else {
      if ($speed > _MIN_SPEED) {
        $speed -= _RESISTANCE;

        if ($speed < _MIN_SPEED) {
          $speed = _MIN_SPEED;
        }

        $this->{Speed} = $speed;
      }
    }

    $this->MoveModulo($this);
  }

  #changes the player direction to the cursorPos
  sub _ChangeDirection {
    my ($this, $cursorPos) = @_;
    my $playerPos = $this->{Position};
    my $vector = $cursorPos->Substract($playerPos);
    my $x = $vector->{X};
    my $y = $vector->{Y};
    my $length = sqrt(($x * $x) + ($y * $y));
    $vector = $vector->Divide($length);
    $this->{DirectionLooking} = $vector;

    if ($this->{IsMoving}) {
      $this->{Direction} = $vector;
    }
  }

  #sets the shooting flag true
  sub StartShooting {
    my ($this) = @_;
    $this->{IsShooting} = TRUE;
  }

  #sets shooting flag false and resets shooting cooldown
  sub StopShooting {
    my ($this) = @_;
    $this->{IsShooting} = FALSE;
    $this->{ShootCounter} =_SHOT_COOLDOWN;
  }

  #shoots when possible
  sub _Shoot {
    my ($this) = @_;
    if ($this->{IsShooting} == FALSE) {return;}

    #only shoot every X time
    my $counter = $this->{ShootCounter};

    if ($counter < _SHOT_COOLDOWN) {
      $this->{ShootCounter} = $counter + 1;
      return;
    }

    $this->{ShootCounter} = 0;
    $this->{_logic}->AddBullet(GameElement::Bullet->new($this->{Position}, $this->{DirectionLooking}));
  }

};

package GameElement::Bullet; {
  use parent -norequire, 'GameElement';

  #creates new bullet
  sub new {
    my ($class, $position, $direction) = @_;

    my $id = UI::CreateBullet($position);

    return bless {
      Position  => $position,
      Direction => $direction,
      Speed     => 10,
      Id        => $id
    }, ref($class)||$class||__PACKAGE__;
  }

  #updates bullet position
  sub Update {
    my ($this) = @_;
    $this->Move($this);
  }
};

package GameElement::Asteroid; {
  use parent -norequire, 'GameElement';
  use Math::Trig;
  use Switch;
  use FindBin qw( $Bin );


  use constant {
    FALSE  => 0,
    TRUE   => 1,
    _IMAGE_NAME => "asteroid1.png",

    #asteroid sizes
    Small  => 30,
    Medium => 50,
    Large    => 90,

    #asteroid speeds
    Slow   => 2,
    Normal => 4,
    Fast   => 7
  };


  my $imageSmall;
  my $imageMedium;
  my $imageLarge;

  sub Initialize {
    my $spritePath = File::Spec->catfile($Bin, _IMAGE_NAME);
    $imageSmall = ImageManipulation::CreateImage($spritePath, Small, Small);
    $imageMedium = ImageManipulation::CreateImage($spritePath, Medium, Medium);
    $imageLarge = ImageManipulation::CreateImage($spritePath, Large, Large);
  }

  #creates a large asteroid
  sub new {
    my ($class, $fieldSize, $logic) = @_;
    my $direction = $class->_GetRandomDirection();
    my $image = $imageLarge;
    my $position = _CalculatePosition($fieldSize);

    my $id = UI::CreateCanvasElement($image, $position);

    return bless {
      Position  => $position,
      Size      => Size->new(Large, Large),
      CanSplit  => TRUE,
      Direction => $direction,
      _logic    => $logic,
      FieldSize => $fieldSize,
      Speed     => Slow,
      Id        => $id,
      Image     => $image
    }, ref($class)||$class||__PACKAGE__;
  }

  #creates a smaller asteroid after split
  sub _new {
    my ($class, $position, $size, $canSplit, $direction, $logic, $fieldSize, $speed) = @_;
    my $image = $imageMedium;

    if ($size->{Width} == Medium) {
      $image = $imageMedium;
    } else {
      $image = $imageSmall;
    }

    my $id = UI::CreateCanvasElement($image, $position);

    return bless {
      Position  => $position,
      Size      => $size,
      CanSplit  => $canSplit,
      Direction => $direction,
      _logic    => $logic,
      FieldSize => $fieldSize,
      Speed     => $speed,
      Id        => $id,
      Image     => $image
    }, ref($class)||$class||__PACKAGE__;
  }

  #returns a random direction
  sub _GetRandomDirection {
    my $x = rand(2) -1;
    my $y = sqrt(1 - ($x * $x));

    if (rand(2) -1 < 0) {
      $y = -$y;
    }

    return Point->new($x, $y);
  }

  #randomizes asteroid position somewhere at the fieldBorder
  sub _CalculatePosition {
    my ($fieldSize) = @_;
    my $case = int(rand(4));
    my $x = int(rand($fieldSize->{Width}));
    my $y = int(rand($fieldSize->{Height}));

    switch($case) {
      case 0 {
        $x = 0;
        $y = int(rand($fieldSize->{Height}));
      }
      case 1 {
        $x = $fieldSize->{Width};
        $y = int(rand($fieldSize->{Height}));
      }
      case 2 {
        $x = int(rand($fieldSize->{Width}));
        $y = 0;
      }
      case 3 {
        $x = int(rand($fieldSize->{Width}));
        $y = $fieldSize->{Height};
      }
    };

    return Point->new($x, $y);
  }

  #moves asteroid
  sub Update {
    my ($this) = @_;
    $this->MoveModulo($this);
  }

  #splits asteroid into 2 smaller ones
  #returns: smaller asteroid
  sub Split {
    my ($this, $bulletDirection) = @_;
    my $size;
    my $canSplit;
    my $speed;

    #medium one
    if ($this->{Size}->{Width} == Large) {
      $size = Size->new(Medium, Medium);
      $speed = Normal;
      $canSplit = TRUE;
      $this->{Image} = $imageMedium;

      #small one
    } else {
      $size = Size->new(Small, Small);
      $speed = Fast;
      $canSplit = FALSE;
      $this->{Image} = $imageSmall;
    }

    $this->{Size} = $size;
    $this->{CanSplit} = $canSplit;
    $this->{Direction} = _GenerateSplitDirection($bulletDirection);
    $this->{Speed} = $speed;

    UI::DeleteElement($this->{Id});
    $this->{Id} = UI::CreateCanvasElement($this->{Image}, $this->{Position});
    return GameElement::Asteroid->_new($this->{Position}, $size, $canSplit, _GenerateSplitDirection($bulletDirection), $this->{_logic}, $this->{FieldSize}, $speed);
  }

  sub _GenerateSplitDirection() {
    my ($bulletDirection) = @_;
    my $pi = Math::Trig::pi();

    #bullet direction - 90° - random between 0-180°
    my $angle = atan2($bulletDirection->{Y}, -$bulletDirection->{X}) - rand($pi);

    return Point->new(sin($angle), cos($angle));
  }


};

package ImageManipulation; {
  use Tk;
  use Tk::PNG;
  use FindBin qw( $Bin );
  use Math::Trig;
  my $mw;

  #needed for accessing photo method
  sub SetMw {
    ($mw) = @_;
  }

  #creates an image, scaled to the given width and height
  sub CreateImage {
    my ($path, $width, $height) = @_;

    my $image = $mw->Photo(-file => $path);
    return ScaleImage($image, $width, $height);
  }

  sub SetPixel {
    my ($image, $x, $y, @color) = @_;
    my $color = RgbToHex(@color);
    #dont draw if black
    unless ($color eq '#000000') {
      $image->put($color, -to => $x, $y);
    }
  }

  #scales image into the target with the target bounds
  sub ScaleImage {
    my ($image, $width, $height) = @_;
    my $target = CreateTempImage($width, $height);
    my $factorX = $image->width / $width;
    my $factorY = $image->height / $height;

    for (my $y = 0; $y < $height; ++$y) {
      for (my $x = 0; $x < $width; ++$x) {
        SetPixel($target, $x, $y, $image->get($x * $factorX, $y * $factorY));
      }
    }

    return ($target);
  }

  sub RotateImage() {
    my ($image, $angle) = @_;
    my $width = $image->width;
    my $height = $image->height;
    my $center = Point->new($width / 2, $height / 2);
    my $bounds = _CalculateBounds(Size->new($width, $height), $center, $angle);
    my $target = CreateTempImage($bounds->{Size}->{Width}, $bounds->{Size}->{Height});
    my $offset = $bounds->{Location};
    $angle = (180 - $angle) * (Math::Trig::pi() / 180); #to radiant
    my $sin = sin($angle);
    my $cos = cos($angle);

    for (my $y = 0; $y < $width * 2; ++$y) {
      for (my $x = 0; $x < $height * 2; ++$x) {
        my $ogPoint = _RotatePointSinCos(Point->new($x, $y), $center, $sin, $cos);
        my $pX = $ogPoint->{X};
        my $pY = $ogPoint->{Y};

        if ($pX >= 0 && $pY >= 0 && $pX < $width && $pY < $height) {
          my $posX = $x - $offset->{X};
          my $posY = $y - $offset->{Y};
          SetPixel($target, $posX, $posY, $image->get($pX, $pY));
        }
      }
    }

    return $target;
  }

  sub _CalculateBounds() {
    my ($size, $center, $angle) = @_;
    my @corners = (Point->Empty(),
      Point->new($size->{Width}, 0),
      Point->new($size->{Width}, $size->{Height}),
      Point->new(0, $size->{Height}),
    );
    my $length = scalar @corners;
    my @rotatedCorners;

    #rotate the 4 corners
    for (my $i = 0; $i < $length; ++$i) {
      $rotatedCorners[$i] = RotatePoint($corners[$i], $center, $angle); #todo: convert angle beforehand
    }

    #find the smallest and biggest coordinates of the rotated corners
    my $first = $rotatedCorners[0];
    my $smallestX = $first->{X};
    my $biggestX = $first->{X};
    my $smallestY = $first->{Y};
    my $biggestY = $first->{Y};

    for (my $i = 1; $i < $length; ++$i) {
      my $current = $rotatedCorners[$i];
      my $cX = $current->{X};
      my $cY = $current->{Y};

      if ($cX < $smallestX) {
        $smallestX = $cX;
      }
      if ($cX > $biggestX) {
        $biggestX = $cX;
      }
      if ($cY < $smallestY) {
        $smallestY = $cY;
      }
      if ($cY > $biggestY) {
        $biggestY = $cY;
      }
    }

    #return their rectangle
    return (Rectangle->new(Point->new($smallestX, $smallestY), Size->new($biggestX - $smallestX, $biggestY - $smallestY)));
  }

  #takes degree angle
  sub RotatePoint() {
    my ($point, $center, $angle) = @_;
    return (_RotatePoint($point, $center, $angle * (Math::Trig::pi() / 180)));
  }

  #takes radiant angle
  sub _RotatePoint() {
    my ($point, $center, $angle) = @_;
    return (_RotatePointSinCos($point, $center, sin($angle), cos ($angle)));
  }

  #todo: should be overload of _RotatePoint
  sub _RotatePointSinCos() {
    my ($point, $center, $sin, $cos) = @_;

    my $x = $point->{X} - $center->{X};
    my $y = $point->{Y} - $center->{Y};

    return (Point->new(
      $cos * $x - $sin * $y + $center->{X},
      $sin * $x - $cos * $y + $center->{Y}
    ));
  }

  #workaround to get a scaled image
  sub CreateTempImage {
    my ($width, $height) = @_;
    return ($mw->Photo(-file => File::Spec->catfile($Bin, 'temp.png'), -width => $width, -height => $height));
  }

  sub RgbToHex {
    my (@values) = @_;
    return (sprintf ("#%2.2X%2.2X%2.2X",$values[0],$values[1],$values[2]));
  }
}

package Utils; {
  sub ReadText {
    my ($filePath) = @_;
    my $text;

    open(my $fh, '<', $filePath) or die $!;

    while(<$fh>){
      $text = $text . $_;
    }

    close($fh);

    return $text;
  }

  sub ReadAllLines {
    my ($filePath) = @_;
    my @lines;
    my $i = 0;

    open(my $fh, '<', $filePath) or die $!;

    while(<$fh>){
      $lines[$i++] = $_;
    }
    close($fh);

    return @lines;
  }

  sub WriteText {
    my ($filePath, $text) = @_;

    open(my $fh, '>', $filePath) or die $!;
    print $fh $text;
    close ($fh);
  }
}