#!perl
use strict;
use warnings;
use utf8;
use Tk;

package MainLogic; {
  use constant {
    FALSE => 0,
    TRUE  => 1
  };

  my $fieldSize = Size->new(900, 900);
  my $asteroidAmount = 10;
  my $isGamerOver = FALSE;
  my $player;
  my @bullets;
  my @asteroids;
  my %keys;

  #tk elements
  my $mw = Tk::MainWindow->new();
  my $canvas = $mw->Canvas(-width => $fieldSize->{Width}, -height => $fieldSize->{Height})->pack();

  Main();

  sub Main {
    $player = Player->new(
      Point->new($fieldSize->{Width} / 2,
        $fieldSize->{Height} / 2),
      Size->new(25, 25),
      'darkblue',
      __PACKAGE__,
      $fieldSize);

    %keys = (
      Move  => 'w',
      Shoot => 'q'
    );

    $mw->title("Spaceship");
    $player->{Id} = CreateCanvasElement($player, $player->{Color});

    for (my $i = 0; $i < $asteroidAmount; ++$i) {
      my $asteroid = Asteroid->new($fieldSize, __PACKAGE__);

      push(@asteroids, $asteroid);
      $asteroid->{Id} = CreateCanvasElement($asteroid, 'grey');
    }

    $mw->bind('<Any-KeyPress>', \&KeyPressed);
    $mw->bind('<Any-KeyRelease>', \&KeyReleased);
    $mw->repeat(20, \&Update);
    $mw->MainLoop();
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

    foreach my $bullet (@bullets) {
      $bullet->Update();
    }

    foreach my $asteroid (@asteroids) {
      $asteroid->Update();

      if (Utils::IntersectsWith($player, $asteroid)) {
        $canvas->createText(400, 450, -text=>"You Lost!");
        $isGamerOver = TRUE;
      }
    }

    CheckCollision();
    Draw();
  }

  sub CheckCollision {
    my $asteroidCount = scalar @asteroids;
    my $itemDeleted = FALSE;


    for (my $i = 0; $i < $asteroidCount; ++$i) {
      my $bulletCount = scalar @bullets;
      #print "count: $bulletCount \n";

      for (my $j = 0; $j < $bulletCount,; ++$j) {
        if (Utils::Contains($asteroids[$i], $bullets[$j]->{Position})) {
          $itemDeleted = TRUE;

          splice(@asteroids, $i, 1);
          splice(@bullets, $j, 1);
          $canvas->delete($asteroids[$i]->{Id});
          $canvas->delete($bullets[$j]->{Id});
          last;
        }
      }
    }

    if ($itemDeleted) {
      my $c = scalar @bullets;
      print "new count: $c \n";
      exit;
    }
  }

  sub Draw() {
    my $count = scalar @asteroids;

    for (my $i = 0; $i < $count; ++$i) {
      DrawCanvasElement($asteroids[$i]);
    }

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
      SPEED      => 10,
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
      SPEED     => 8,
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

    Small  => 20,
    Medium => 50,
    Big    => 70
  };

  sub new {
    my ($class, $fieldSize, $logic) = @_;

    my $x = int(rand($fieldSize->{Width}));
    my $y = int(rand($fieldSize->{Height}));

    my $direction = Point->new(rand(2) -1, rand(2) -1);

    return bless {
      Position  => Point->new($x, $y),
      Size      => Size->new(Big, Big),
      Direction => $direction,
      _logic    => $logic,
      FieldSize => $fieldSize,
      SPEED     => 3,
      Id        => 0
    }, ref($class)||$class||__PACKAGE__;
  }

  sub Update {
    my ($this) = @_;
    Utils::MoveModulo($this);
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
    my $amount = $object->{Direction}->Multiply($object->{SPEED});
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
