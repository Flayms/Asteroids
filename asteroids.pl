#!perl
use strict;
use warnings;
use utf8;
use Tk;
use Tk::PNG;
use Tk::JPEG;
use Scalar::Util;
use Math::Trig;
use Switch;
# TODO: move uses where they belong
# TODO: ressourcing (magic strings and numbers)
package MainLogic; {
  use FindBin qw( $Bin );
  use File::Spec;

  use constant {
    FALSE                   => 0,
    TRUE                    => 1,
    LEVEL_COMPLETION_POINTS => 1000
  };

  my $fieldSize = Size->new(900, 900);

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
  my $levelIndex = 1;
  my $isGamerOver = FALSE;
  my $player;
  my $score = 0;
  my $scoreId;
  my @bullets;
  my @asteroids;
  my %keys = (
    Move  => 'w',
    Shoot => 'q'
  );

  #tk elements
  my $mw = Tk::MainWindow->new();
  my $canvas = $mw->Canvas(-width => $fieldSize->{Width}, -height => $fieldSize->{Height})->pack();

  Main();

  sub Main {
    #create background
    my $image = $mw->Photo(-format => 'png', -file => File::Spec->catfile($Bin, 'stars.png'));
    $canvas->createImage(0, 0, -image=>$image, anchor => 'nw');

    CreatePlayer();
    CreateScore();
    CreateAsteroids();
    SetupWindow();

    $mw->MainLoop();
  }

  #creates the player and his canvas element
  sub CreatePlayer {
    $player = GameElement::Player->new(
      Point->new($fieldSize->{Width} / 2,
        $fieldSize->{Height} / 2),
      Size->new(25, 25),
      'yellow',
      __PACKAGE__,
      $fieldSize);

    $player->{Id} = CreateCanvasElement($player, $player->{Color});
  }

  #creates the score text
  sub CreateScore {
    $scoreId = $canvas->createText(60, 20, -text => "Level: $levelIndex | Score: $score", -fill => "white");
  }

  #creates the asteroids for the level and their canvas elements
  sub CreateAsteroids {
    my $amount = $asteroidAmounts[$levelIndex - 1];
    for (my $i = 0; $i < $amount; ++$i) {
      my $asteroid = GameElement::Asteroid->new($fieldSize, __PACKAGE__);

      $asteroids[$i] = $asteroid;
      $asteroid->{Id} = CreateCanvasElement($asteroid, 'grey');
    }
  }

  #creates a gameElement on the canvas
  sub CreateCanvasElement {
    my ($element, $color) = @_;

    my $x = $element->{Position}->{X};
    my $y = $element->{Position}->{Y};
    my $width = $element->{Size}->{Width};
    my $height = $element->{Size}->{Height};
    # TODO: path
    my $filename = "D:/SVN/HMP/Perl/trunk/Projects/AZUBI Playground/FIAE 2018/asteroids/asteroid1.png";
    return $canvas->createOval($x, $y, $x + $width, $y + $height, -fill => $color);
    #return $canvas->createImage($x, $y, -image=> $canvas->Photo(-file=>$filename));
}

  # sets up the tk window
  sub SetupWindow {
    $mw->title("Spaceship");
    $mw->bind('<Any-KeyPress>', \&KeyPressed);
    $mw->bind('<Any-KeyRelease>', \&KeyReleased);
    $mw->repeat(20, \&Update);
  }

  #updates the game and draws it
  sub Update {
    if ($isGamerOver) { return;}

    $player->Update(GetCursorPosition());
    UpdateBullets();
    UpdateAsteroids();

    HandleAsteroidBulletCollision();
    HandleLevelCompletion();

    Draw();
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
        $canvas->delete($bullet->{Id});
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
        $canvas->createText(400, 450, -text => "You Lost!", -fill => "white");
        $isGamerOver = TRUE;
      }
    }
  }

  #handles collision for each asteroid and bullet
  # TODO: method makes things from different abstraction layers UI and BL
  sub HandleAsteroidBulletCollision {

    for (my $i = scalar @asteroids - 1; $i >= 0; --$i) {
      my $asteroid = $asteroids[$i];

      for (my $j = scalar @bullets- 1; $j >= 0; --$j) {
        my $bullet = $bullets[$j];

        if ($asteroid->Contains($bullet->{Position})) {

          $canvas->delete($bullet->{Id});
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
      $newAsteroid->{Id} = CreateCanvasElement($asteroid, 'grey');
      push (@asteroids, $newAsteroid);
    } else {

      $canvas->delete($asteroid->{Id});
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
      DrawCanvasElement($asteroids[$i]);
    }

    $canvas->delete($scoreId);
    CreateScore();
    DrawCanvasElement($player);
    DrawBullets();
  }

  #handles key press
  sub KeyPressed {
    my $key = $_[0]->XEvent->K;

    if ($key eq $keys{Move}) {
      $player->StartMoving();

    } elsif ($key eq $keys{Shoot}) {
      $player->StartShooting();
    }
  }

  #handles key release
  sub KeyReleased {
    my $key = $_[0]->XEvent->K;

    if ($key eq $keys{Move}) {
      $player->StopMoving();

    } elsif ($key eq $keys{Shoot}) {
      $player->StopShooting();
    }
  }

  #adds a bullet to array and canvas
  sub AddBullet {
    my ($this, $bullet) = @_;

    push(@bullets, $bullet);

    my $x = $bullet->{Position}->{X};
    my $y = $bullet->{Position}->{Y};

    $bullet->{Id} = $canvas->createOval($x, $y, $x + 10, $y + 10, -fill => 'red');
  }

  #draws a gameElement on the canvas
  sub DrawCanvasElement {
    my ($element) = @_;
    my $x = $element->{Position}->{X};
    my $y = $element->{Position}->{Y};
    my $width = $element->{Size}->{Width};
    my $height = $element->{Size}->{Height};
    #$canvas->coords($element->{Id}, $x, $y);
    $canvas->coords($element->{Id}, $x, $y, $x + $width, $y + $height);
  }

  #draws all bullets on the canvas
  sub DrawBullets {
    my $count = scalar @bullets;
    for (my $i=0; $i < $count; ++$i) {
      my $bullet = $bullets[$i];
      my $x = $bullet->{Position}->{X};
      my $y = $bullet->{Position}->{Y};

      $canvas->coords($bullet->{Id}, $x, $y, $x + 10, $y + 10);
    }
  }

  #gets the current cursor position relative to the canvas
  sub GetCursorPosition {
    my $x = $canvas->pointerx - $canvas->rootx;
    my $y = $canvas->pointery - $canvas->rooty;

    return Point->new($x, $y);
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
    my ($class) = @_;
    return bless {
      X => 0,
      Y => 0
    }, ref($class)||$class||__PACKAGE__;
  }

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
    my ($object) = @_;
    my $amount = $object->{Direction}->Multiply($object->{Speed});
    $object->{Position} = $object->{Position}->Add($amount);
  }

  #moves this and keeps it in field
  sub MoveModulo {
    my ($object) = @_;
    Move($object);
    my $position = $object->{Position};
    my $fieldSize = $object->{FieldSize};
    $object->{Position} = Point->new($position->{X} % $fieldSize->{Width}, $position->{Y} % $fieldSize->{Height});
  }

  #checks if of this contain a specific point
  sub Contains {
    my ($object, $point)   = @_;
    my $objPos = $object->{Position};
    my $objX = $objPos->{X};
    my $objY = $objPos->{Y};
    my $pX = $point->{X};
    my $pY = $point->{Y};
    my $size = $object->{Size};

    if ($pX >= $objX and
      $pX <= $objX + $size->{Width} and
      $pY >= $objY and
      $pY <= $objY + $size->{Height}) {
      return TRUE;
    }
    return FALSE;
  }

  #checks if this intersects with another gameElement
  sub IntersectsWith {
    my ($object, $otherObj) = @_;
    my $l1 = $object->{Position};
    my $r1 = Point->new($l1->{X} + $object->{Size}->{Width}, $l1->{Y} + $object->{Size}->{Height});
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

  use constant {
    FALSE => 0,
    TRUE  => 1
  };

  #creates a new player
  sub new {
    my ($class, $position, $size, $color, $mainLogic, $fieldSize) = @_;
    return bless {
      Position   => $position,
      Size       => $size,
      Color      => $color,
      _logic     => $mainLogic,
      FieldSize => $fieldSize,
      Direction  => Point->Empty(), #the direction in which the ship is flying
      DirectionLooking => Point->Empty(), #the direction in which the ship is looking
      IsMoving   => FALSE,
      Speed      => 0,
      _MAX_SPEED => 10,
      _ACCELERATION => 0.6,
      _RESISTANCE => 0.2,
      IsShooting => FALSE,
      ShootCounter => 7, #should be done with timer
      SHOT_COOLDOWN => 7,
      Id => 0
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
    my $MAX_SPEED = $this->{_MAX_SPEED};

    if ($this->{IsMoving}) {
      #accelerate player if not at max speed
      if ($speed <= $MAX_SPEED) {
        $speed += $this->{_ACCELERATION};

        if ($speed > $MAX_SPEED) {
          $speed = $MAX_SPEED;
        }

        $this->{Speed} = $speed;
      }

    }
    else {
      if ($speed > 0) {
        #slow player down if not still
        $speed -= $this->{_RESISTANCE};

        if ($speed < 0) {
          $speed = 0;
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
    my $vector = $cursorPos->Substract($playerPos); #todo: implement in direction property
    my $length = sqrt(($vector->{X} * $vector->{X}) + ($vector->{Y} * $vector->{Y}));
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
    $this->{ShootCounter} =$this->{SHOT_COOLDOWN};
  }

  #shoots when possible
  sub _Shoot {
    my ($this) = @_;
    if ($this->{IsShooting} == FALSE) {return;}

    #only shoot every X time
    my $counter = $this->{ShootCounter};

    if ($counter < $this->{SHOT_COOLDOWN}) {
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
    return bless {
      Position  => $position,
      Direction => $direction,
      Speed     => 8,
      Id        => 0
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

  use constant {
    FALSE  => 0,
    TRUE   => 1,

    #asteroid sizes
    Small  => 30,
    Medium => 50,
    Big    => 90,

    #asteroid speeds
    Slow   => 2,
    Normal => 4,
    Fast   => 7
  };

  #creates a big asteroid
  sub new {
    my ($class, $fieldSize, $logic) = @_;
    my $direction = $class->_GetRandomDirection();

    return bless {
      Position  => _CalculatePosition($fieldSize),
      Size      => Size->new(Big, Big),
      CanSplit => TRUE,
      Direction => $direction,
      _logic    => $logic,
      FieldSize => $fieldSize,
      Speed     => Slow,
      Id        => 0
    }, ref($class)||$class||__PACKAGE__;
  }

  #creates a smaller asteroid after split
  sub _new {
    my ($class, $position, $size, $canSplit, $direction, $logic, $fieldSize, $speed) = @_;
    return bless {
      Position  => $position,
      Size      => $size,
      CanSplit  => $canSplit,
      Direction => $direction,
      _logic    => $logic,
      FieldSize => $fieldSize,
      Speed     => $speed,
      Id        => 0
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
    }

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
    if ($this->{Size}->{Width} == Big) {
      $size = Size->new(Medium, Medium);
      $speed = Normal;
      $canSplit = TRUE;

      #small one
    } else {
      $size = Size->new(Small, Small);
      $speed = Fast;
      $canSplit = FALSE;
    }

    $this->{Size} = $size;
    $this->{CanSplit} = $canSplit;
    $this->{Direction} = _GenerateSplitDirection($bulletDirection);
    $this->{Speed} = $speed;
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