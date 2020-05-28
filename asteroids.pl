#!perl
use strict;
use warnings;
use utf8;
use Tk;
use Scalar::Util;
use Switch;

package MainLogic; {
  use constant {
    FALSE                   => 0,
    TRUE                    => 1,
    LEVEL_COMPLETION_POINTS => 1000
  };

  my $fieldSize = Size->new(900, 900);
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
    $canvas->createRectangle(0, 0, $fieldSize->{Width}, $fieldSize->{Height}, -fill => 'black');
    CreatePlayer();
    CreateScore();
    CreateAsteroids();

    $mw->title("Spaceship");
    $mw->bind('<Any-KeyPress>', \&KeyPressed);
    $mw->bind('<Any-KeyRelease>', \&KeyReleased);
    $mw->repeat(20, \&Update);
    $mw->MainLoop();
  }

  sub CreateScore {
    $scoreId = $canvas->createText(60, 20, -text => "Level: $levelIndex | Score: $score", -fill => "white");
  }

  sub CreatePlayer {
    $player = Player->new(
      Point->new($fieldSize->{Width} / 2,
        $fieldSize->{Height} / 2),
      Size->new(25, 25),
      'blue',
      __PACKAGE__,
      $fieldSize);

    $player->{Id} = CreateCanvasElement($player, $player->{Color});
  }

  sub CreateAsteroids {
    my $amount = @asteroidAmounts[$levelIndex - 1];
    for (my $i = 0; $i < $amount; ++$i) {
      my $asteroid = Asteroid->new($fieldSize, __PACKAGE__);

      $asteroids[$i] = $asteroid;
      $asteroid->{Id} = CreateCanvasElement($asteroid, 'grey');
    }
  }

  sub CreateCanvasElement {
    my ($element, $color) = @_;

    my $x = $element->{Position}->{X};
    my $y = $element->{Position}->{Y};
    my $width = $element->{Size}->{Width};
    my $height = $element->{Size}->{Height};
    return $canvas->createOval($x, $y, $x + $width, $y + $height, -fill => $color);
  }

  sub Update {
    if ($isGamerOver) {
      return;
    }

    $player->Update(GetCursorPosition());

    for (my $i = scalar @bullets - 1; $i >= 0; --$i) {
      my $bullet = $bullets[$i];
      $bullet->Update();

      #delete bullet if not in field anymore
      if ($bullet->{Position}->{X} > $fieldSize->{Width} or $bullet->{Position}->{Y} > $fieldSize->{Height}) {
        $canvas->delete($bullet->{Id});
        splice(@bullets, $i, 1);
      }
    }

    foreach my $asteroid (@asteroids) {
      $asteroid->Update();

      if (Utils::IntersectsWith($player, $asteroid)) {
        $canvas->createText(400, 450, -text => "You Lost!", -fill => "white");
        $isGamerOver = TRUE;
      }
    }

    HandleCollision();

    my $count = scalar @asteroids;

    if ($count == 0) {
      $score += LEVEL_COMPLETION_POINTS;
      ++$levelIndex;
      CreateAsteroids();
    }

    Draw();
  }

  sub HandleCollision {
    my $asteroidCount = scalar @asteroids;

    for (my $i = $asteroidCount - 1; $i >= 0; --$i) {
      my $bulletCount = scalar @bullets;
      my $asteroid = $asteroids[$i];

      for (my $j = $bulletCount - 1; $j >= 0; --$j) {

        if (Utils::Contains($asteroid, $bullets[$j]->{Position})) {
          $canvas->delete($bullets[$j]->{Id});
          splice(@bullets, $j, 1);

          $score += $asteroid->{Size}->{Width};

          if ($asteroid->{CanSplit}) {
            my $newAsteroid =  $asteroid->Split();
            $newAsteroid->{Id} = CreateCanvasElement($asteroid, 'grey');
            push (@asteroids, $newAsteroid);
          } else {
            $canvas->delete($asteroid->{Id});
            splice(@asteroids, $i, 1);
          }
        }
      }
    }
  }

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


  sub KeyPressed {
    my $key = $_[0]->XEvent->K;

    if ($key eq $keys{Move}) { #todo: use switch
      $player->StartMoving();
    }

    if ($key eq $keys{Shoot}) {
      $player->StartShooting();
    }
  }

  sub KeyReleased {
    my $key = $_[0]->XEvent->K;#todo: use switch

    if ($key eq $keys{Move}) {
      $player->StopMoving();
    }

    if ($key eq $keys{Shoot}) {
      $player->StopShooting();
    }
  }

  sub AddBullet {
    my ($this, $bullet) = @_;

    push(@bullets, $bullet);

    my $x = $bullet->{Position}->{X};
    my $y = $bullet->{Position}->{Y};

    $bullet->{Id} = $canvas->createOval($x, $y, $x + 10, $y + 10, -fill => 'red');
  }

  sub DrawCanvasElement {
    my ($element) = @_;
    my $x = $element->{Position}->{X};
    my $y = $element->{Position}->{Y};
    my $width = $element->{Size}->{Width};
    my $height = $element->{Size}->{Height};
    $canvas->coords($element->{Id}, $x, $y, $x + $width, $y + $height);
  }

  sub DrawBullets {
    my $count = scalar @bullets;
    for (my $i=0; $i < $count; ++$i) {
      my $bullet = $bullets[$i];
      my $x = $bullet->{Position}->{X};
      my $y = $bullet->{Position}->{Y};

      $canvas->coords($bullet->{Id}, $x, $y, $x + 10, $y + 10);
    }
  }

  sub GetCursorPosition {
    my $x = $canvas->pointerx - $canvas->rootx;
    my $y = $canvas->pointery - $canvas->rooty;

    return Point->new($x, $y);
  }

}

package Point; {

  sub new {
    my ($class, $x, $y) = @_;
    return bless {
      X => $x,
      Y => $y
    }, ref($class)||$class||__PACKAGE__;
  }

  sub Empty {
    my ($class) = @_;
    return bless {
      X => 0,
      Y => 0
    }, ref($class)||$class||__PACKAGE__;
  }

  sub Add {
    my ($this, $point) = @_;
    return(Point->new($this->{X} + $point->{X}, $this->{Y} + $point->{Y}))
  }

  sub Substract {
    my ($this, $point) = @_;
    return(Point->new($this->{X} - $point->{X}, $this->{Y} - $point->{Y}))
  }

  sub Multiply {
    my ($this, $value) = @_;
    return(Point->new($this->{X} * $value, $this->{Y} * $value))
  }

};

package Size; {
  sub new {
    my ($class, $width, $height) = @_;
    return bless {
      Width => $width,
      Height => $height
    }, ref($class)||$class||__PACKAGE__;
  }
};

package Player; {
  use constant {
    FALSE => 0,
    TRUE  => 1
  };

  sub new {
    my ($class, $position, $size, $color, $mainLogic, $fieldSize) = @_;
    return bless {
      Position   => $position,
      Size       => $size,
      Color      => $color,
      _logic     => $mainLogic,
      FieldSize => $fieldSize,
      Direction  => Point->Empty(),
      IsMoving   => FALSE,
      Speed      => 10,
      IsShooting => FALSE,
      ShootCounter => 7, #should be done with timer
      SHOOT_COUNTER_MAX => 7,
      Id => 0
    }, ref($class)||$class||__PACKAGE__;
  }

  sub StartMoving {
    my ($this) = @_;
    $this->{IsMoving} = TRUE;
  }

  sub StopMoving {
    my ($this) = @_;
    $this->{IsMoving} = FALSE;

  }

  sub Update {
    my ($this, $cursorPos) = @_;

    $this->_ChangeDirection($cursorPos);

    if ($this->{IsMoving}) {
      Utils::MoveModulo($this);
    }

    $this->_Shoot();
  }

  sub _ChangeDirection {
    my ($this, $cursorPos) = @_;
    my $playerPos = $this->{Position};
    my $vector = $cursorPos->Substract($playerPos); #todo: implement in direction property
    my $bigger;
    my $x = abs($vector->{X});
    my $y = abs($vector->{Y});

    if ($x > $y) {
      $bigger = $x;
    } else {
      $bigger = $y;
    }

    $vector = Point->new(($vector->{X}/$bigger), ($vector->{Y}/$bigger));
    $this->{Direction} = $vector;
  }

  sub StartShooting {
    my ($this) = @_;
    $this->{IsShooting} = TRUE;
  }

  sub StopShooting {
    my ($this) = @_;
    $this->{IsShooting} = FALSE;
    $this->{ShootCounter} =$this->{SHOOT_COUNTER_MAX};
  }

  sub _Shoot {
    my ($this) = @_;
    if ($this->{IsShooting} == FALSE) {return;}

    #only shoot every X time
    my $counter = $this->{ShootCounter};

    if ($counter < $this->{SHOOT_COUNTER_MAX}) {
      $this->{ShootCounter} = $counter + 1;
      return;
    }

    $this->{ShootCounter} = 0;


    $this->{_logic}->AddBullet(Bullet->new($this->{Position}, $this->{Direction}));
  }

};

package Bullet; {

  sub new {
    my ($class, $position, $direction) = @_;
    return bless {
      Position  => $position,
      Direction => $direction,
      Speed     => 8,
      Id        => 0
    }, ref($class)||$class||__PACKAGE__;
  }

  sub Update {
    my ($this) = @_;
    Utils::Move($this);
  }
};

package Asteroid; {
  use constant {
    FALSE  => 0,
    TRUE   => 1,

    Small  => 30,
    Medium => 50,
    Big    => 90,

    Slow   => 2,
    Normal => 4,
    Fast   => 7
  };

  sub new {
    my ($class, $fieldSize, $logic) = @_;
    my $direction = Point->new(rand(2) -1, rand(2) -1);

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

  sub Update {
    my ($this) = @_;
    Utils::MoveModulo($this);
  }

  sub Split {
    my ($this) = @_;
    my $newDirection = Point->new(-$this->{Direction}->{Y}, $this->{Direction}->{X});
    my $size;
    my $canSplit;
    my $speed;

    if ($this->{Size}->{Width} == Big) {
      $size = Size->new(Medium, Medium);
      $speed = Normal;
      $canSplit = TRUE;
    }

    if ($this->{Size}->{Width} == Medium) {
      $size = Size->new(Small, Small);
      $speed = Fast;
      $canSplit = FALSE;
    }

    $this->{Size} = $size;
    $this->{CanSplit} = $canSplit;
    $this->{Direction} = Point->new($this->{Direction}->{Y}, -$this->{Direction}->{X});
    $this->{Speed} = $speed;
    return Asteroid->_new($this->{Position}, $size, $canSplit, $newDirection, $this->{_logic}, $this->{FieldSize}, $speed);
  }

};

package Utils; {

  use constant {
    FALSE => 0,
    TRUE  => 1
  };

  #moves game object by its direction and speed
  sub Move {
    my ($object) = @_;
    my $amount = $object->{Direction}->Multiply($object->{Speed});
    $object->{Position} = $object->{Position}->Add($amount);
  }

  sub MoveModulo {
    my ($object) = @_;
    Move($object);
    my $position = $object->{Position};
    my $fieldSize = $object->{FieldSize};
    $object->{Position} = Point->new($position->{X} % $fieldSize->{Width}, $position->{Y} % $fieldSize->{Height});
  }

  #checks if the bounds of a game object contain a specific point
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
